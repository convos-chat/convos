package daemon

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"strings"
)

const (
	networkTCP  = "tcp"
	networkUnix = "unix"
)

var (
	errUnknownScheme = errors.New("unknown listen scheme")
	errMissingPort   = errors.New("listen address is missing port")
)

// ListenerConfig holds the parsed configuration for a single listen address.
type ListenerConfig struct {
	Network  string
	Address  string
	CertFile string
	KeyFile  string
	IsHTTPS  bool
}

func parseListen(listen string) (ListenerConfig, error) {
	// Normalize scheme to lowercase before parsing so HTTP://, HTTPS://, etc. all work.
	if idx := strings.Index(listen, "://"); idx != -1 {
		listen = strings.ToLower(listen[:idx]) + listen[idx:]
	}

	// Go's url.Parse doesn't handle percent-encoded hosts in http+unix:// well,
	// so we parse those manually.
	if strings.HasPrefix(listen, "http+unix://") {
		return parseUnixListen(listen[len("http+unix://"):])
	}

	u, err := url.Parse(listen)
	if err != nil {
		return ListenerConfig{}, fmt.Errorf("invalid listen URL: %w", err)
	}

	switch u.Scheme {
	case "http":
		return parseTCPListen(u, false)
	case "https":
		return parseTCPListen(u, true)
	default:
		return ListenerConfig{}, fmt.Errorf("%w: %s", errUnknownScheme, u.Scheme)
	}
}

func parseTCPListen(u *url.URL, https bool) (ListenerConfig, error) {
	cfg := ListenerConfig{
		Network: networkTCP,
		Address: u.Host,
		IsHTTPS: https,
	}

	if https {
		cfg.CertFile = u.Query().Get("cert")
		cfg.KeyFile = u.Query().Get("key")
	}

	if _, _, err := net.SplitHostPort(cfg.Address); err != nil {
		return ListenerConfig{}, fmt.Errorf("%w: %s", errMissingPort, cfg.Address)
	}

	return cfg, nil
}

func parseUnixListen(rest string) (ListenerConfig, error) {
	cfg := ListenerConfig{Network: networkUnix}

	pathStr, _, _ := strings.Cut(rest, "?")

	path, err := url.PathUnescape(pathStr)
	if err != nil {
		return ListenerConfig{}, fmt.Errorf("invalid unix socket path: %w", err)
	}
	cfg.Address = path

	return cfg, nil
}
