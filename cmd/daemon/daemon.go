// Package daemon implements the "daemon" command which starts the Convos server.
package daemon

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
	"github.com/convos-chat/convos/pkg/server"
	"github.com/convos-chat/convos/pkg/storage"
	"github.com/urfave/cli/v3"
)

var ErrUnknownScheme = errors.New("unknown connection scheme")

// connectionProvider implements core.ConnectionProvider
type connectionProvider struct{}

func (p *connectionProvider) NewConnection(rawURL string, user *core.User) (core.Connection, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, err
	}

	switch u.Scheme {
	case "irc", "ircs":
		return irc.NewConnection(rawURL, user), nil
	default:
		return nil, fmt.Errorf(" %s is not known: %w", u.Scheme, ErrUnknownScheme)
	}
}

func Command() *cli.Command {
	return &cli.Command{
		Name:  "daemon",
		Usage: "Start the Convos daemon",
		Flags: []cli.Flag{
			&cli.StringSliceFlag{
				Name:    "listen",
				Aliases: []string{"l"},
				Usage:   "List of addresses and ports to listen on",
			},
		},
		Action: func(ctx context.Context, cmd *cli.Command) error {
			cfg, err := config.Load()
			if err != nil {
				return fmt.Errorf("failed to load config: %w", err)
			}

			listenFlags := cmd.StringSlice("listen")
			if len(listenFlags) == 0 {
				listenFlags = []string{cfg.Listen}
			} else {
				// Update cfg.Listen to the first listen flag so BaseURL defaults correctly
				cfg.Listen = listenFlags[0]
			}

			if os.Geteuid() == 0 {
				slog.Warn("ATTENTION! Convos should not be run as root. It is recommended to run as a normal user.")
			}

			// Auto-discover PEM files in home directory, matching Perl behavior:
			// files ending in -key.pem → CONVOS_TLS_KEY, other .pem → CONVOS_TLS_CERT
			discoverPEMFiles(cfg.Home)

			// Initialize Core
			backend := storage.NewFileBackend(cfg.Home)
			c := core.New(
				core.WithHome(cfg.Home),
				core.WithBackend(backend),
				core.WithConnectionProvider(&connectionProvider{}),
				core.WithProfileDefaults(cfg.ProfileDefaults.MaxBulkSize, cfg.ProfileDefaults.MaxMessageLength, strings.Split(cfg.ProfileDefaults.ServiceAccounts, ",")),
				core.WithConnectDelay(cfg.ConnectDelay),
			)

			if startErr := c.Start(); startErr != nil {
				return fmt.Errorf("failed to start core: %w", startErr)
			}

			// Create authenticator based on configuration
			authenticator, err := auth.NewAuthenticator(c, cfg.Auth)
			if err != nil {
				return fmt.Errorf("failed to create authenticator: %w", err)
			}
			slog.Info("Using authentication provider", "provider", authenticator.Name())

			// Initialize Server
			srv := server.New(c, cfg, authenticator)

			var servers []*http.Server
			var wg sync.WaitGroup

			for _, listenStr := range listenFlags {
				listener, httpServer, err := createListener(ctx, cfg, srv, listenStr)
				if err != nil {
					return err
				}

				servers = append(servers, httpServer)
				wg.Add(1)

				go func(l net.Listener, s *http.Server, addr string) {
					defer wg.Done()
					slog.Info("Server started", "listen", addr)
					if serveErr := s.Serve(l); serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
						slog.Error("Server failed", "listen", addr, "error", serveErr)
					}
				}(listener, httpServer, listenStr)
			}

			// Wait for interrupt signal
			sigChan := make(chan os.Signal, 1)
			signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
			<-sigChan

			slog.Info("Shutting down servers...")
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			for _, s := range servers {
				if err := s.Shutdown(shutdownCtx); err != nil {
					slog.Error("Server shutdown failed", "error", err)
				}
			}

			wg.Wait()
			slog.Info("Servers stopped gracefully")
			return nil
		},
	}
}

// createListener parses a listen address string and returns a ready net.Listener and http.Server.
func createListener(ctx context.Context, cfg *config.Config, handler http.Handler, listenStr string) (net.Listener, *http.Server, error) {
	listenCfg, err := parseListen(listenStr)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse listen address %q: %w", listenStr, err)
	}

	// Remove stale unix socket files before listening
	if listenCfg.Network == networkUnix {
		if err = os.RemoveAll(listenCfg.Address); err != nil {
			return nil, nil, fmt.Errorf("failed to remove socket file %q: %w", listenCfg.Address, err)
		}
	}

	lc := net.ListenConfig{}
	listener, err := lc.Listen(ctx, listenCfg.Network, listenCfg.Address)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to listen on %s %s: %w", listenCfg.Network, listenCfg.Address, err)
	}

	if listenCfg.IsHTTPS {
		listener, err = wrapTLS(listener, listenCfg, cfg.Home)
		if err != nil {
			return nil, nil, err
		}
	}

	httpServer := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
	}

	return listener, httpServer, nil
}

// wrapTLS wraps a listener with TLS, resolving certificate paths from the listen config,
// environment variables (CONVOS_TLS_CERT/CONVOS_TLS_KEY), or auto-generating a self-signed cert.
func wrapTLS(listener net.Listener, listenCfg ListenerConfig, homeDir string) (net.Listener, error) {
	certFile := listenCfg.CertFile
	keyFile := listenCfg.KeyFile

	if certFile == "" || keyFile == "" {
		certFile = os.Getenv("CONVOS_TLS_CERT")
		keyFile = os.Getenv("CONVOS_TLS_KEY")
	}

	if certFile == "" || keyFile == "" {
		if err := os.MkdirAll(homeDir, 0o700); err != nil {
			return nil, fmt.Errorf("failed to create cert directory: %w", err)
		}
		certFile = filepath.Join(homeDir, "server.crt")
		keyFile = filepath.Join(homeDir, "server.key")
		if err := ensureCert(certFile, keyFile); err != nil {
			return nil, fmt.Errorf("failed to ensure certificate: %w", err)
		}
		slog.Info("Using generated certificate", "cert", certFile, "key", keyFile)
	}

	tlsCert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("failed to load TLS key pair: %w", err)
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{tlsCert},
		MinVersion:   tls.VersionTLS12,
	}
	return tls.NewListener(listener, tlsConfig), nil
}

// discoverPEMFiles scans a directory for PEM files and sets CONVOS_TLS_CERT/CONVOS_TLS_KEY
// environment variables if not already set. Matches the Perl behavior in script/convos.
func discoverPEMFiles(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		fullPath := filepath.Join(dir, name)

		if strings.HasSuffix(name, "-key.pem") && os.Getenv("CONVOS_TLS_KEY") == "" {
			os.Setenv("CONVOS_TLS_KEY", fullPath)
		} else if strings.HasSuffix(name, ".pem") && os.Getenv("CONVOS_TLS_CERT") == "" {
			os.Setenv("CONVOS_TLS_CERT", fullPath)
		}
	}
}
