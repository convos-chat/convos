// Package config provides configuration management for the Convos application.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/convos-chat/convos/pkg/auth"
	"github.com/kelseyhightower/envconfig"
)

// Config holds the application configuration.
type Config struct {
	Home             string        `envconfig:"CONVOS_HOME"`
	Listen           string        `envconfig:"CONVOS_LISTEN" default:"http://localhost:8080"`
	Mode             string        `envconfig:"CONVOS_MODE" default:"production"`
	ReverseProxy     string        `envconfig:"CONVOS_REVERSE_PROXY"`
	SecureCookies    *bool         `envconfig:"CONVOS_SECURE_COOKIES"`
	SessionSecret    string        `envconfig:"CONVOS_SESSION_SECRET"`
	RequestBaseURL   string        `envconfig:"CONVOS_REQUEST_BASE_URL"`
	OrganizationName string        `envconfig:"CONVOS_ORGANIZATION_NAME" default:"Convos"`
	OrganizationURL  string        `envconfig:"CONVOS_ORGANIZATION_URL" default:"https://convos.chat"`
	Contact          string        `envconfig:"CONVOS_CONTACT" default:"mailto:root@localhost"`
	DefaultTheme     string        `envconfig:"CONVOS_DEFAULT_THEME" default:"convos"`
	DefaultScheme    string        `envconfig:"CONVOS_DEFAULT_SCHEME" default:"light"`
	MaxUploadSize    int64         `envconfig:"CONVOS_MAX_UPLOAD_SIZE" default:"40000000"`
	ConnectDelay     time.Duration `envconfig:"CONVOS_CONNECT_DELAY" default:"100ms"`
	WebhookNetworks  string        `envconfig:"CONVOS_WEBHOOK_NETWORKS" default:"140.82.112.0/20,192.30.252.0/22,185.199.108.0/22"`
	InviteExpiry     time.Duration `envconfig:"CONVOS_INVITE_EXPIRY" default:"24h"`
	Auth             auth.ProviderConfig
	ProfileDefaults  ProfileDefaults
}

type ProfileDefaults struct {
	MaxBulkSize      int    `envconfig:"CONVOS_MAX_BULK_SIZE" default:"3"`
	MaxMessageLength int    `envconfig:"CONVOS_MAX_MESSAGE_LENGTH" default:"512"`
	ServiceAccounts  string `envconfig:"CONVOS_SERVICE_ACCOUNTS" default:"chanserv,nickserv"`
}

// IsDevelopment returns true if running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.Mode == "development"
}

func (c *Config) ReverseProxyEnabled() bool {
	return c.ReverseProxy != ""
}

// Load loads configuration from environment variables.
func Load() (*Config, error) {
	var c Config
	if err := envconfig.Process("convos", &c); err != nil {
		return nil, fmt.Errorf("failed to process config: %w", err)
	}

	if c.Home == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("failed to get user home directory: %w", err)
		}
		c.Home = filepath.Join(homeDir, ".convos")
	}

	return &c, nil
}
