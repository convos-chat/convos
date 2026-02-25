package coretest

import (
	"log/slog"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

// testConnection is a minimal Connection implementation for core tests.
type testConnection struct {
	*core.BaseConnection
}

func newTestConnection(rawURL string, user *core.User) *testConnection {
	return &testConnection{
		BaseConnection: core.NewBaseConnection(rawURL, user),
	}
}

func (c *testConnection) Connect() error            { return nil }
func (c *testConnection) Disconnect() error         { return nil }
func (c *testConnection) Send(_, _ string) error    { return nil }
func (c *testConnection) List(_ string) (map[string]any, error) {
	return map[string]any{"conversations": []map[string]any{}, "n_conversations": 0, "done": false}, nil
}
func (c *testConnection) LogServerError(msg string) { slog.Info("[Server log]", "msg", msg) }

var _ core.Connection = (*testConnection)(nil)

func TestNewConnection(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	if conn.User() != user {
		t.Error("User() should return the parent user")
	}

	if conn.URL() == nil {
		t.Fatal("URL() should not be nil")
	}

	if conn.URL().Host != "irc.libera.chat:6697" {
		t.Errorf("URL().Host = %q, want %q", conn.URL().Host, "irc.libera.chat:6697")
	}
}

func TestConnectionID(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	tests := []struct {
		url      string
		expected string
	}{
		{"irc://irc.libera.chat:6697", "irc-libera"},
		{"irc://chat.freenode.net:6667", "irc-freenode"},
		{"irc://localhost:6667", "irc-localhost"},
		{"ircs://irc.oftc.net:6697", "ircs-oftc"},
	}

	for _, tt := range tests {
		conn := newTestConnection(tt.url, user)
		if conn.ID() != tt.expected {
			t.Errorf("ID() for %q = %q, want %q", tt.url, conn.ID(), tt.expected)
		}
	}
}

func TestConnectionName(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	// Auto-generated name from URL
	if conn.Name() != "libera" {
		t.Errorf("Name() = %q, want %q", conn.Name(), "libera")
	}

	// Set custom name
	conn.SetName("Libera Chat")
	if conn.Name() != "Libera Chat" {
		t.Errorf("Name() = %q, want %q", conn.Name(), "Libera Chat")
	}
}

func TestConnectionState(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	// Initial state
	if conn.State() != core.StateDisconnected {
		t.Errorf("State() = %q, want %q", conn.State(), core.StateDisconnected)
	}

	// Wanted state default
	if conn.WantedState() != core.StateConnected {
		t.Errorf("WantedState() = %q, want %q", conn.WantedState(), core.StateConnected)
	}

	// Set wanted state
	conn.SetWantedState(core.StateDisconnected)
	if conn.WantedState() != core.StateDisconnected {
		t.Errorf("WantedState() = %q, want %q", conn.WantedState(), core.StateDisconnected)
	}
}

func TestConnectionNick(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()

	tests := []struct {
		email    string
		url      string
		expected string
	}{
		{"john.doe@example.com", "irc://irc.libera.chat", "john_doe"},
		{"alice@example.com", "irc://irc.libera.chat", "alice"},
		{"test-user@example.com", "irc://irc.libera.chat", "test_user"},
		{"user@example.com", "irc://irc.libera.chat?nick=custom", "custom"},
	}

	for _, tt := range tests {
		user := core.NewUser(tt.email, c)
		conn := newTestConnection(tt.url, user)
		if conn.Nick() != tt.expected {
			t.Errorf("Nick() for email=%q, url=%q = %q, want %q",
				tt.email, tt.url, conn.Nick(), tt.expected)
		}
	}
}

func TestConnectionOnConnectCommands(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	// Initially empty
	if len(conn.OnConnectCommands()) != 0 {
		t.Error("OnConnectCommands() should be empty initially")
	}

	// Set commands
	cmds := []string{"/msg NickServ identify password", "/join #channel"}
	conn.SetOnConnectCommands(cmds)

	got := conn.OnConnectCommands()
	if len(got) != 2 {
		t.Errorf("OnConnectCommands() = %d items, want 2", len(got))
	}
}

func TestConnectionConversations(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	// Initially empty
	if len(conn.Conversations()) != 0 {
		t.Error("Conversations() should be empty initially")
	}

	// Add conversation
	conv := core.NewConversation(testChannel, conn)
	conn.AddConversation(conv)

	convs := conn.Conversations()
	if len(convs) != 1 {
		t.Errorf("Conversations() = %d, want 1", len(convs))
	}

	// Get conversation
	found := conn.GetConversation(testChannel)
	if found != conv {
		t.Error("GetConversation() should return the added conversation")
	}

	// Case insensitive lookup
	found = conn.GetConversation("#TEST")
	if found != conv {
		t.Error("GetConversation() should be case insensitive")
	}

	// Remove conversation
	conn.RemoveConversation(testChannel)
	if len(conn.Conversations()) != 0 {
		t.Error("Conversation should be removed")
	}
}

func TestConnectionToData(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conn.SetName("Libera")
	conn.SetOnConnectCommands([]string{"/join #test"})

	// Add a conversation
	conv := core.NewConversation(testChannel, conn)
	conv.SetTopic("Test channel")
	conn.AddConversation(conv)

	// Without persist (no conversations, includes state)
	data := conn.ToData(false)
	if data.ID != conn.ID() {
		t.Errorf("ID = %q, want %q", data.ID, conn.ID())
	}
	if data.Name != "Libera" {
		t.Errorf("Name = %q, want %q", data.Name, "Libera")
	}
	if data.State != core.StateDisconnected {
		t.Errorf("State = %q, want %q", data.State, core.StateDisconnected)
	}
	if len(data.Conversations) != 0 {
		t.Error("Conversations should be empty when persist=false")
	}

	// With persist (includes conversations, no state)
	data = conn.ToData(true)
	if data.State != "" {
		t.Error("State should be empty when persist=true")
	}
	if len(data.Conversations) != 1 {
		t.Errorf("Conversations = %d, want 1", len(data.Conversations))
	}
}

func TestPrettyConnectionName(t *testing.T) {
	t.Parallel()

	tests := []struct {
		host     string
		expected string
	}{
		{"irc.libera.chat", "libera"},
		{"irc.libera.chat:6697", "libera"},
		{"chat.freenode.net", "freenode"},
		{"localhost", "localhost"},
		{"localhost:6667", "localhost"},
		{"irc.example.com", "example"},
		{"127.0.0.1", "127.0.0.1"},
	}

	for _, tt := range tests {
		got := core.PrettyConnectionName(tt.host)
		if got != tt.expected {
			t.Errorf("PrettyConnectionName(%q) = %q, want %q", tt.host, got, tt.expected)
		}
	}
}
