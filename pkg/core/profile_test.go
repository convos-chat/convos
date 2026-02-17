package core

import (
	"net/url"
	"testing"
)

func TestNewConnectionProfile(t *testing.T) {
	t.Parallel()
	c := New()
	p := NewConnectionProfile("irc://irc.libera.chat", c)

	if p.ID() != "irc-libera" {
		t.Errorf("ID() = %q, want %q", p.ID(), "irc-libera")
	}

	if p.MaxBulkMessageSize() != 3 {
		t.Errorf("MaxBulkMessageSize() = %d, want 3", p.MaxBulkMessageSize())
	}

	if p.MaxMessageLength() != 512 {
		t.Errorf("MaxMessageLength() = %d, want 512", p.MaxMessageLength())
	}

	expectedSA := []string{"chanserv", "nickserv"}
	gotSA := p.ServiceAccounts()
	if len(gotSA) != len(expectedSA) {
		t.Errorf("ServiceAccounts() = %v, want %v", gotSA, expectedSA)
	}
}

func TestConnectionProfileEnvOverrides(t *testing.T) {
	t.Parallel()

	c := New()
	// Mock environment
	env := map[string]string{
		"CONVOS_MAX_BULK_MESSAGE_SIZE": "5",
		"CONVOS_MAX_MESSAGE_LENGTH":    "1024",
		"CONVOS_SERVICE_ACCOUNTS":      "serv1,serv2,serv3",
	}
	c.getenv = func(key string) string {
		return env[key]
	}

	p := NewConnectionProfile("irc://irc.libera.chat", c)

	if p.MaxBulkMessageSize() != 5 {
		t.Errorf("MaxBulkMessageSize() = %d, want 5", p.MaxBulkMessageSize())
	}

	if p.MaxMessageLength() != 1024 {
		t.Errorf("MaxMessageLength() = %d, want 1024", p.MaxMessageLength())
	}

	gotSA := p.ServiceAccounts()
	if len(gotSA) != 3 || gotSA[0] != "serv1" || gotSA[2] != "serv3" {
		t.Errorf("ServiceAccounts() = %v, want [serv1 serv2 serv3]", gotSA)
	}
}

func TestConnectionProfileFindServiceAccount(t *testing.T) {
	t.Parallel()
	c := New()
	p := NewConnectionProfile("irc://irc.libera.chat", c)

	if p.FindServiceAccount("NickServ") != "NickServ" {
		t.Error("FindServiceAccount should find NickServ (case-insensitive match)")
	}

	if p.FindServiceAccount("ChanServ") != "ChanServ" {
		t.Error("FindServiceAccount should find ChanServ (case-insensitive match)")
	}

	if p.FindServiceAccount("regular_user") != "" {
		t.Error("FindServiceAccount should not find regular_user")
	}
}

func TestCoreConnectionProfileCaching(t *testing.T) {
	t.Parallel()
	c := New()
	u1, _ := parseURL("irc://irc.libera.chat")
	u2, _ := parseURL("irc://irc.libera.chat:6697")

	p1 := c.ConnectionProfile(u1)
	p2 := c.ConnectionProfile(u2)

	if p1 != p2 {
		t.Error("ConnectionProfile() should return the same instance for the same host")
	}

	if len(c.ConnectionProfiles()) != 1 {
		t.Errorf("ConnectionProfiles() = %d, want 1", len(c.ConnectionProfiles()))
	}
}

func TestConnectionProfilePersistence(t *testing.T) {
	t.Parallel()
	backend := NewMemoryBackend()
	c := New(WithBackend(backend))

	u, _ := parseURL("irc://irc.libera.chat")
	p := c.ConnectionProfile(u)
	p.mu.Lock()
	p.maxMessageLength = 256
	p.mu.Unlock()

	if err := p.Save(); err != nil {
		t.Fatalf("Save() error: %v", err)
	}

	// Create a new core with the same backend
	c2 := New(WithBackend(backend))
	if err := c2.Start(); err != nil {
		t.Fatalf("Start() error: %v", err)
	}

	p2 := c2.ConnectionProfile(u)
	if p2.MaxMessageLength() != 256 {
		t.Errorf("MaxMessageLength() = %d, want 256 (loaded from backend)", p2.MaxMessageLength())
	}
}

func TestConnectionProfileLink(t *testing.T) {
	t.Parallel()
	c := New()
	user, _ := c.User(testEmail)
	conn := newTestConnection("irc://irc.libera.chat", user)

	p := conn.Profile()
	if p == nil {
		t.Fatal("Profile() should not be nil")
	}

	if p.ID() != "irc-libera" {
		t.Errorf("Profile().ID() = %q, want %q", p.ID(), "irc-libera")
	}
}

func TestConnectionProfileSplitMessage(t *testing.T) {
	t.Parallel()
	c := New()
	p := NewConnectionProfile("irc://localhost", c)
	p.mu.Lock()
	p.maxMessageLength = 10
	p.maxBulkMessageSize = 10 // Large enough for these tests
	p.mu.Unlock()

	tests := []struct {
		input    string
		expected []string
	}{
		{"short", []string{"short"}},
		{"long message that needs splitting", []string{"long", "message", "that needs", "splitting"}},
		{"verylongword", []string{"verylongw", "ord"}},
	}

	for _, tt := range tests {
		got := p.SplitMessage(tt.input)
		if len(got) != len(tt.expected) {
			t.Errorf("SplitMessage(%q) length = %d, want %d", tt.input, len(got), len(tt.expected))
			continue
		}
		for i := range got {
			if got[i] != tt.expected[i] {
				t.Errorf("SplitMessage(%q)[%d] = %q, want %q", tt.input, i, got[i], tt.expected[i])
			}
		}
	}
}

func TestConnectionProfileTooLongMessages(t *testing.T) {
	t.Parallel()
	c := New()
	p := NewConnectionProfile("irc://localhost", c)
	p.mu.Lock()
	p.maxMessageLength = 10
	p.maxBulkMessageSize = 3
	p.mu.Unlock()

	if !p.TooLongMessages([]string{"1", "2", "3"}) {
		t.Error("3 messages should be 'too long' since maxBulkMessageSize is 3 (limit is >= size)")
	}

	if !p.TooLongMessages([]string{"1", "2", "3", "4"}) {
		t.Error("4 messages should be 'too long'")
	}

	if !p.TooLongMessages([]string{"this message is too long"}) {
		t.Error("message exceeding maxMessageLength should be 'too long'")
	}
}

func parseURL(raw string) (*url.URL, error) {
	return url.Parse(raw)
}
