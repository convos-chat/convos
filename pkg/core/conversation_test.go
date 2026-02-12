package core

import (
	"testing"
)

func TestNewConversation(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	conv := NewConversation(testChannel, conn)

	if conv.Connection() != conn {
		t.Error("Connection() should return the parent connection")
	}

	if conv.Name() != testChannel {
		t.Errorf("Name() = %q, want %q", conv.Name(), testChannel)
	}

	if conv.ID() != testChannel {
		t.Errorf("ID() = %q, want %q", conv.ID(), testChannel)
	}
}

func TestConversationIsPrivate(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	tests := []struct {
		name      string
		isPrivate bool
	}{
		{"#channel", false},
		{"&channel", false},
		{"+channel", false},
		{"!channel", false},
		{"nickname", true},
		{"some_user", true},
	}

	for _, tt := range tests {
		conv := NewConversation(tt.name, conn)
		if conv.IsPrivate() != tt.isPrivate {
			t.Errorf("IsPrivate() for %q = %v, want %v", tt.name, conv.IsPrivate(), tt.isPrivate)
		}
	}
}

func TestConversationTopic(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Initially empty
	if conv.Topic() != "" {
		t.Errorf("Topic() = %q, want empty", conv.Topic())
	}

	// Set topic
	conv.SetTopic("Welcome to the test channel!")
	if conv.Topic() != "Welcome to the test channel!" {
		t.Errorf("Topic() = %q, want %q", conv.Topic(), "Welcome to the test channel!")
	}
}

func TestConversationPassword(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation("#secret", conn)

	// Initially empty
	if conv.Password() != "" {
		t.Errorf("Password() = %q, want empty", conv.Password())
	}

	// Set password
	conv.SetPassword("channelkey")
	if conv.Password() != "channelkey" {
		t.Errorf("Password() = %q, want %q", conv.Password(), "channelkey")
	}
}

func TestConversationFrozen(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Initially not frozen
	if conv.Frozen() != "" {
		t.Errorf("Frozen() = %q, want empty", conv.Frozen())
	}

	// Freeze
	conv.SetFrozen("You have been kicked")
	if conv.Frozen() != "You have been kicked" {
		t.Errorf("Frozen() = %q, want %q", conv.Frozen(), "You have been kicked")
	}

	// Unfreeze
	conv.SetFrozen("")
	if conv.Frozen() != "" {
		t.Errorf("Frozen() = %q, want empty", conv.Frozen())
	}
}

func TestConversationNotifications(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Initially zero
	if conv.Notifications() != 0 {
		t.Errorf("Notifications() = %d, want 0", conv.Notifications())
	}

	// Increment
	conv.IncNotifications()
	conv.IncNotifications()
	if conv.Notifications() != 2 {
		t.Errorf("Notifications() = %d, want 2", conv.Notifications())
	}

	// Set
	conv.SetNotifications(5)
	if conv.Notifications() != 5 {
		t.Errorf("Notifications() = %d, want 5", conv.Notifications())
	}
}

func TestConversationUnread(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Initially zero
	if conv.Unread() != 0 {
		t.Errorf("Unread() = %d, want 0", conv.Unread())
	}

	// Increment
	conv.IncUnread()
	conv.IncUnread()
	conv.IncUnread()
	if conv.Unread() != 3 {
		t.Errorf("Unread() = %d, want 3", conv.Unread())
	}

	// Set
	conv.SetUnread(10)
	if conv.Unread() != 10 {
		t.Errorf("Unread() = %d, want 10", conv.Unread())
	}
}

func TestConversationInfo(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Initially empty
	info := conv.Info()
	if len(info) != 0 {
		t.Errorf("Info() = %v, want empty", info)
	}

	// Set info
	conv.SetInfo("mode", "+nt")
	conv.SetInfo("users", 42)

	info = conv.Info()
	if info["mode"] != "+nt" {
		t.Errorf("Info()[mode] = %v, want %q", info["mode"], "+nt")
	}
	if info["users"] != 42 {
		t.Errorf("Info()[users] = %v, want 42", info["users"])
	}

	// Info should be a copy
	info["mode"] = "changed"
	if conv.Info()["mode"] != "+nt" {
		t.Error("Info() should return a copy")
	}
}

func TestConversationToData(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	conv.SetTopic("Test topic")
	conv.SetPassword("secret")
	conv.SetFrozen("kicked")
	conv.SetNotifications(3)
	conv.SetUnread(10)
	conv.SetInfo("mode", "+nt")

	// Without persist (no password)
	data := conv.ToData(false)
	if data.ConnectionID != conn.ID() {
		t.Errorf("ConnectionID = %q, want %q", data.ConnectionID, conn.ID())
	}
	if data.ConversationID != testChannel {
		t.Errorf("ConversationID = %q, want %q", data.ConversationID, testChannel)
	}
	if data.Name != testChannel {
		t.Errorf("Name = %q, want %q", data.Name, testChannel)
	}
	if data.Topic != "Test topic" {
		t.Errorf("Topic = %q, want %q", data.Topic, "Test topic")
	}
	if data.Password != "" {
		t.Error("Password should be empty when persist=false")
	}
	if data.Frozen != "kicked" {
		t.Errorf("Frozen = %q, want %q", data.Frozen, "kicked")
	}
	if data.Notifications != 3 {
		t.Errorf("Notifications = %d, want 3", data.Notifications)
	}
	if data.Unread != 10 {
		t.Errorf("Unread = %d, want 10", data.Unread)
	}

	// With persist (includes password)
	data = conv.ToData(true)
	if data.Password != "secret" {
		t.Errorf("Password = %q, want %q", data.Password, "secret")
	}
}

func TestConversationIDCaseInsensitive(t *testing.T) {
	t.Parallel()

	c := New()
	user := NewUser(testEmail, c)
	conn := newTestConnection("irc://irc.libera.chat:6697", user)

	conv := NewConversation("#TestChannel", conn)
	if conv.ID() != "#testchannel" {
		t.Errorf("ID() = %q, want lowercase %q", conv.ID(), "#testchannel")
	}
}
