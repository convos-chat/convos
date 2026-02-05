// Package config provides configuration management for the Convos application.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/kelseyhightower/envconfig"
)

// Config holds the application configuration.
type Config struct {
	Home             string `envconfig:"CONVOS_HOME"`
	Listen           string `envconfig:"CONVOS_LISTEN" default:"http://localhost:8080"`
	Mode             string `envconfig:"CONVOS_MODE" default:"production"`
	ReverseProxy     bool   `envconfig:"CONVOS_REVERSE_PROXY"`
	SecureCookies    *bool  `envconfig:"CONVOS_SECURE_COOKIES"`
	SessionSecret    string `envconfig:"CONVOS_SESSION_SECRET"`
	OrganizationName string `envconfig:"CONVOS_ORGANIZATION_NAME" default:"Convos"`
	OrganizationURL  string `envconfig:"CONVOS_ORGANIZATION_URL" default:"https://convos.chat"`
	Contact          string `envconfig:"CONVOS_CONTACT" default:"mailto:root@localhost"`
	CertFile         string `envconfig:"CONVOS_CERT"`
	KeyFile          string `envconfig:"CONVOS_KEY"`
	WebhookNetworks  string `envconfig:"CONVOS_WEBHOOK_NETWORKS" default:"140.82.112.0/20,192.30.252.0/22,185.199.108.0/22"`
}

// IsDevelopment returns true if running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.Mode == "development"
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

	if c.SecureCookies == nil {
		secure := c.IsHTTPS()
		c.SecureCookies = &secure
	}

	return &c, nil
}

// IsHTTPS returns true if both CertFile and KeyFile are set.
func (c *Config) IsHTTPS() bool {
	return c.CertFile != "" && c.KeyFile != ""
}
