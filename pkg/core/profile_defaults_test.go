package core

import (
	"net/url"
	"testing"
)

const defaultIRCURL = "irc://irc.libera.chat"

func TestConnectionProfileInheritance(t *testing.T) {
	t.Parallel()
	c := New()

	// Setup default connection
	defaultURL, _ := url.Parse(defaultIRCURL)
	c.Settings().SetDefaultConnection(defaultIRCURL)

	// Get default profile and modify it
	defaultProfile := c.ConnectionProfile(defaultURL)
	defaultProfile.mu.Lock()
	defaultProfile.maxMessageLength = 999
	defaultProfile.mu.Unlock()

	// Create new connection
	newURL, _ := url.Parse("irc://irc.example.com")
	newProfile := c.ConnectionProfile(newURL)

	if newProfile.MaxMessageLength() != 999 {
		t.Errorf("MaxMessageLength() = %d, want 999 (inherited from default)", newProfile.MaxMessageLength())
	}
}

func TestConnectionProfileInheritanceWithEnv(t *testing.T) {
	t.Parallel()

	c := New()
	// Mock environment
	env := map[string]string{
		"CONVOS_MAX_MESSAGE_LENGTH": "123",
	}
	c.getenv = func(key string) string {
		return env[key]
	}

	// Setup default connection
	defaultURL, _ := url.Parse(defaultIRCURL)
	c.Settings().SetDefaultConnection(defaultIRCURL)

	// Get default profile and modify it
	defaultProfile := c.ConnectionProfile(defaultURL)
	defaultProfile.mu.Lock()
	defaultProfile.maxMessageLength = 999
	defaultProfile.mu.Unlock()

	// Create new connection
	newURL, _ := url.Parse("irc://irc.example.com")
	newProfile := c.ConnectionProfile(newURL)

	if newProfile.MaxMessageLength() != 123 {
		t.Errorf("MaxMessageLength() = %d, want 123 (override by env)", newProfile.MaxMessageLength())
	}
}
