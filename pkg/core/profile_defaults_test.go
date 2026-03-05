package core_test

import (
	"net/url"
	"testing"

	"github.com/convos-chat/convos/pkg/test"
)

const defaultIRCURL = "irc://irc.libera.chat"

func TestConnectionProfileInheritance(t *testing.T) {
	t.Parallel()
	c := test.NewTestCore()

	// Setup default connection
	defaultURL, _ := url.Parse(defaultIRCURL)
	c.Settings().SetDefaultConnection(defaultIRCURL)

	// Get default profile and modify it
	defaultProfile := c.ConnectionProfile(defaultURL)
	defaultProfile.SetMaxMessageLength(999)

	// Create new connection
	newURL, _ := url.Parse("irc://irc.example.com")
	newProfile := c.ConnectionProfile(newURL)

	if newProfile.MaxMessageLength() != 999 {
		t.Errorf("MaxMessageLength() = %d, want 999 (inherited from default)", newProfile.MaxMessageLength())
	}
}
