package daemon

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/server"
	"github.com/convos-chat/convos/pkg/storage"
	"github.com/urfave/cli/v3"
)

func Command() *cli.Command {
	return &cli.Command{
		Name:  "daemon",
		Usage: "Start the Convos daemon",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "listen",
				Aliases: []string{"l"},
				Usage:   "Address and port to listen on",
			},
		},
		Action: func(ctx context.Context, cmd *cli.Command) error {
			cfg, err := config.Load()
			if err != nil {
				return fmt.Errorf("failed to load config: %w", err)
			}

			if listen := cmd.String("listen"); listen != "" {
				cfg.Listen = listen
			}

			if os.Geteuid() == 0 {
				slog.Warn("ATTENTION! Convos should not be run as root. It is recommended to run as a normal user.")
			}

			slog.Info("Starting Convos daemon", "listen", cfg.Listen)

			// Parse the listen URL to extract host:port
			listenURL, err := url.Parse(cfg.Listen)
			if err != nil {
				return fmt.Errorf("invalid listen URL: %w", err)
			}
			addr := listenURL.Host
			if addr == "" {
				addr = "localhost:8080"
			}

			// Initialize Core
			backend := storage.NewFileBackend(cfg.Home)
			c := core.New(core.WithHome(cfg.Home), core.WithBackend(backend))
			if err := c.Start(); err != nil {
				return fmt.Errorf("failed to start core: %w", err)
			}

			// Initialize Server
			srv := server.New(c, cfg)

			httpServer := &http.Server{
				Addr:              addr,
				Handler:           srv,
				ReadHeaderTimeout: 10 * time.Second,
			}

			// Graceful shutdown
			go func() {
				var err error
				if cfg.IsHTTPS() {
					slog.Info("Starting server with TLS", "cert", cfg.CertFile, "key", cfg.KeyFile)
					err = httpServer.ListenAndServeTLS(cfg.CertFile, cfg.KeyFile)
				} else {
					err = httpServer.ListenAndServe()
				}

				if err != nil && !errors.Is(err, http.ErrServerClosed) {
					slog.Error("Server failed", "error", err)
					os.Exit(1)
				}
			}()

			slog.Info("Server started", "listen", cfg.Listen)

			// Wait for interrupt signal
			sigChan := make(chan os.Signal, 1)
			signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
			<-sigChan

			slog.Info("Shutting down server...")
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			if err := httpServer.Shutdown(shutdownCtx); err != nil {

				slog.Error("Server shutdown failed", "error", err)
				return err
			}

			slog.Info("Server stopped gracefully")
			return nil
		},
	}
}
