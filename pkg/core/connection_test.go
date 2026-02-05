package core

import (
	"os"
	"testing"
	"time"
)

func TestNewIRCConnection(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

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

	c := New()
	user := NewUser(testEmail, c)

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
		conn := NewIRCConnection(tt.url, user)
		if conn.ID() != tt.expected {
			t.Errorf("ID() for %q = %q, want %q", tt.url, conn.ID(), tt.expected)
		}
	}
}

func TestConnectionName(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)

	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

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

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

	// Initial state
	if conn.State() != StateDisconnected {
		t.Errorf("State() = %q, want %q", conn.State(), StateDisconnected)
	}

	// Wanted state default
	if conn.WantedState() != StateConnected {
		t.Errorf("WantedState() = %q, want %q", conn.WantedState(), StateConnected)
	}

	// Set wanted state
	conn.SetWantedState(StateDisconnected)
	if conn.WantedState() != StateDisconnected {
		t.Errorf("WantedState() = %q, want %q", conn.WantedState(), StateDisconnected)
	}
}

func TestConnectionNick(t *testing.T) {
	t.Parallel()

	c := New()

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
		user := NewUser(tt.email, c)
		conn := NewIRCConnection(tt.url, user)
		if conn.Nick() != tt.expected {
			t.Errorf("Nick() for email=%q, url=%q = %q, want %q",
				tt.email, tt.url, conn.Nick(), tt.expected)
		}
	}
}

func TestConnectionOnConnectCommands(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

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

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

	// Initially empty
	if len(conn.Conversations()) != 0 {
		t.Error("Conversations() should be empty initially")
	}

	// Add conversation
	conv := NewConversation(testChannel, conn)
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

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)
	conn.SetName("Libera")
	conn.SetOnConnectCommands([]string{"/join #test"})

	// Add a conversation
	conv := NewConversation(testChannel, conn)
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
	if data.State != StateDisconnected {
		t.Errorf("State = %q, want %q", data.State, StateDisconnected)
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

func TestConnectionDisconnectWhenWantedDisconnected(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

	// Set wanted state to disconnected
	conn.SetWantedState(StateDisconnected)

	// Connect should fail
	err := conn.Connect()
	if err == nil {
		t.Error("Connect() should fail when wanted state is disconnected")
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
		got := prettyConnectionName(tt.host)
		if got != tt.expected {
			t.Errorf("prettyConnectionName(%q) = %q, want %q", tt.host, got, tt.expected)
		}
	}
}

// TestIRCConnectionIntegration tests the IRC connection against a real server
// when CONVOS_TEST_IRC_SERVER is set (e.g., "irc://localhost:6667")
func TestIRCConnectionIntegration(t *testing.T) {
	t.Parallel()
	serverURL := os.Getenv("CONVOS_TEST_IRC_SERVER")
	if serverURL == "" {
		t.Skip("CONVOS_TEST_IRC_SERVER not set, skipping integration test")
		return
	}

	t.Log("Testing IRC connection against:", serverURL)

	// Create core and user
	c := New()
	user := NewUser("testuser@convos.chat", c)

	// Create connection
	conn := NewIRCConnection(serverURL, user)

	// Test initial state
	if conn.State() != StateDisconnected {
		t.Errorf("Initial state = %q, want %q", conn.State(), StateDisconnected)
	}

	// Connect to server
	t.Log("Connecting to IRC server...")
	if err := conn.Connect(); err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}

	// Wait for connection to establish (with timeout)
	timeout := time.NewTimer(10 * time.Second)
	connected := make(chan bool, 1)

	go func() {
		for {
			if conn.State() == StateConnected {
				connected <- true
				return
			}
			if conn.State() == StateDisconnected {
				connected <- false
				return
			}
			time.Sleep(100 * time.Millisecond)
		}
	}()

	select {
	case success := <-connected:
		if !success {
			t.Error("Connection failed to establish")
		} else {
			t.Log("Successfully connected to IRC server")
		}
	case <-timeout.C:
		t.Error("Connection timeout")
	}

	// If we're connected, test joining a channel and sending a message
	if conn.State() == StateConnected {
		t.Log("Testing channel join and message sending...")

		target := "#test"
		t.Logf("Joining %s...", target)
		if err := conn.client.Join(target); err != nil {
			t.Errorf("Failed to join %s: %v", target, err)
		}

		// Wait a bit for JOIN to complete
		time.Sleep(500 * time.Millisecond)

		if err := conn.Send(target, "Test message from Convos Go integration test"); err != nil {
			t.Errorf("Failed to send message: %v", err)
		} else {
			t.Log("Successfully sent test message")
		}

		// Wait a bit for message to be processed
		time.Sleep(500 * time.Millisecond)
	}

	// Disconnect
	t.Log("Disconnecting from IRC server...")
	if err := conn.Disconnect(); err != nil {
		t.Errorf("Failed to disconnect: %v", err)
	}

	// Wait for disconnection
	timeout = time.NewTimer(5 * time.Second)
	disconnected := make(chan bool, 1)

	go func() {
		for {
			if conn.State() == StateDisconnected {
				disconnected <- true
				return
			}
			time.Sleep(100 * time.Millisecond)
		}
	}()

	select {
	case <-disconnected:
		t.Log("Successfully disconnected from IRC server")
	case <-timeout.C:
		t.Error("Disconnection timeout")
	}

	t.Log("Integration test completed successfully")
}
