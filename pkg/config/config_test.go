package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) { //nolint:paralleltest // modifies environment variables
	// Save current env
	oldHome := os.Getenv("CONVOS_HOME")
	oldListen := os.Getenv("CONVOS_LISTEN")
	defer func() {
		if oldHome != "" {
			os.Setenv("CONVOS_HOME", oldHome)
		} else {
			os.Unsetenv("CONVOS_HOME")
		}
		if oldListen != "" {
			os.Setenv("CONVOS_LISTEN", oldListen)
		} else {
			os.Unsetenv("CONVOS_LISTEN")
		}
	}()

	// Test default values
	os.Unsetenv("CONVOS_HOME")
	os.Unsetenv("CONVOS_LISTEN")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}
	if cfg.Listen != "http://localhost:8080" {
		t.Errorf("Listen = %q, want default", cfg.Listen)
	}
	if cfg.OrganizationName != "Convos" {
		t.Errorf("OrganizationName = %q, want default", cfg.OrganizationName)
	}

	// Test env override
	os.Setenv("CONVOS_HOME", "/tmp/convos")
	os.Setenv("CONVOS_LISTEN", "http://0.0.0.0:3000")
	os.Setenv("CONVOS_REVERSE_PROXY", "true")

	cfg, err = Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}
	if cfg.Home != "/tmp/convos" {
		t.Errorf("Home = %q, want /tmp/convos", cfg.Home)
	}
	if cfg.Listen != "http://0.0.0.0:3000" {
		t.Errorf("Listen = %q, want http://0.0.0.0:3000", cfg.Listen)
	}
	if !cfg.ReverseProxy {
		t.Error("ReverseProxy = false, want true")
	}
}
