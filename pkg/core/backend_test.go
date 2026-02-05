package core

import (
	"testing"
	"time"
)

func TestNewMemoryBackend(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	if b == nil {
		t.Fatal("NewMemoryBackend() returned nil")
	}
}

func TestMemoryBackendUserOperations(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))
	user := NewUser(testEmail, c)
	if err := user.SetPassword("secret"); err != nil {
		t.Fatalf("SetPassword() error: %v", err)
	}
	user.GiveRole(roleAdmin)
	user.SetUID(1)

	// Save user
	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}

	// Load users
	users, err := b.LoadUsers()
	if err != nil {
		t.Fatalf("LoadUsers() error: %v", err)
	}

	if len(users) != 1 {
		t.Fatalf("LoadUsers() returned %d users, want 1", len(users))
	}

	loaded := users[0]
	if loaded.Email != testEmail {
		t.Errorf("Email = %q, want %q", loaded.Email, testEmail)
	}
	if loaded.Password == "" {
		t.Error("Password should be saved")
	}
	if len(loaded.Roles) != 1 || loaded.Roles[0] != roleAdmin {
		t.Errorf("Roles = %v, want [admin]", loaded.Roles)
	}
	if loaded.UID != 1 {
		t.Errorf("UID = %d, want 1", loaded.UID)
	}

	// Update user
	user.GiveRole("moderator")
	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() update error: %v", err)
	}

	users, err = b.LoadUsers()
	if err != nil {
		t.Fatalf("LoadUsers() error after update: %v", err)
	}
	if len(users) != 1 {
		t.Error("SaveUser() should update existing user, not create new")
	}

	// Delete user
	if err := b.DeleteUser(user); err != nil {
		t.Fatalf("DeleteUser() error: %v", err)
	}

	users, err = b.LoadUsers()
	if err != nil {
		t.Fatalf("LoadUsers() error after delete: %v", err)
	}
	if len(users) != 0 {
		t.Errorf("LoadUsers() returned %d users after delete, want 0", len(users))
	}
}

func TestMemoryBackendConnectionOperations(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))
	user := NewUser(testEmail, c)

	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)
	conn.SetName("Libera")
	conn.SetOnConnectCommands([]string{"/join #test"})

	// Save connection
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Load connections
	conns, err := b.LoadConnections(user)
	if err != nil {
		t.Fatalf("LoadConnections() error: %v", err)
	}

	if len(conns) != 1 {
		t.Fatalf("LoadConnections() returned %d connections, want 1", len(conns))
	}

	loaded := conns[0]
	if loaded.Name != "Libera" {
		t.Errorf("Name = %q, want %q", loaded.Name, "Libera")
	}
	if len(loaded.OnConnectCommands) != 1 {
		t.Errorf("OnConnectCommands = %v, want 1 item", loaded.OnConnectCommands)
	}

	// Update connection
	conn.SetName("Libera Chat")
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() update error: %v", err)
	}

	conns, err = b.LoadConnections(user)
	if err != nil {
		t.Fatalf("LoadConnections() error after update: %v", err)
	}
	if len(conns) != 1 {
		t.Error("SaveConnection() should update existing connection")
	}
	if conns[0].Name != "Libera Chat" {
		t.Errorf("Name = %q, want updated %q", conns[0].Name, "Libera Chat")
	}

	// Delete connection
	if err := b.DeleteConnection(conn); err != nil {
		t.Fatalf("DeleteConnection() error: %v", err)
	}

	conns, err = b.LoadConnections(user)
	if err != nil {
		t.Fatalf("LoadConnections() error after delete: %v", err)
	}
	if len(conns) != 0 {
		t.Errorf("LoadConnections() returned %d after delete, want 0", len(conns))
	}
}

func TestMemoryBackendMessageOperations(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)
	conv := NewConversation(testChannel, conn)

	// Save messages
	msgs := []Message{
		{From: "alice", Message: "Hello", Type: "privmsg", Timestamp: time.Now().Unix()},
		{From: "bob", Message: "Hi there", Type: "privmsg", Timestamp: time.Now().Unix()},
		{From: "alice", Message: "How are you?", Type: "privmsg", Timestamp: time.Now().Unix()},
	}

	for _, msg := range msgs {
		if err := b.SaveMessage(conv, msg); err != nil {
			t.Fatalf("SaveMessage() error: %v", err)
		}
	}

	// Load messages
	result, err := b.LoadMessages(conv, MessageQuery{Limit: 10})
	if err != nil {
		t.Fatalf("LoadMessages() error: %v", err)
	}

	if len(result.Messages) != 3 {
		t.Errorf("LoadMessages() returned %d messages, want 3", len(result.Messages))
	}

	if !result.End {
		t.Error("End should be true when all messages are returned")
	}

	// Load with limit
	result, err = b.LoadMessages(conv, MessageQuery{Limit: 2})
	if err != nil {
		t.Fatalf("LoadMessages() with limit error: %v", err)
	}
	if len(result.Messages) != 2 {
		t.Errorf("LoadMessages() with limit=2 returned %d messages, want 2", len(result.Messages))
	}

	// Delete messages
	if err := b.DeleteMessages(conv); err != nil {
		t.Fatalf("DeleteMessages() error: %v", err)
	}

	result, err = b.LoadMessages(conv, MessageQuery{Limit: 10})
	if err != nil {
		t.Fatalf("LoadMessages() error after delete: %v", err)
	}
	if len(result.Messages) != 0 {
		t.Errorf("LoadMessages() after delete returned %d, want 0", len(result.Messages))
	}
}

func TestMemoryBackendNotifications(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))
	user := NewUser(testEmail, c)

	result, err := b.LoadNotifications(user, MessageQuery{Limit: 10})
	if err != nil {
		t.Fatalf("LoadNotifications() error: %v", err)
	}

	if !result.End {
		t.Error("End should be true for empty notifications")
	}

	if len(result.Notifications) != 0 {
		t.Errorf("Notifications = %d, want 0", len(result.Notifications))
	}
}

func TestMemoryBackendDeleteUserCleansConnections(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))
	user := NewUser(testEmail, c)
	conn := NewIRCConnection("irc://irc.libera.chat:6697", user)

	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Verify connection exists
	conns, err := b.LoadConnections(user)
	if err != nil {
		t.Fatalf("LoadConnections() error: %v", err)
	}
	if len(conns) != 1 {
		t.Fatal("Connection should exist before user deletion")
	}

	// Delete user should also clean up connections
	if err := b.DeleteUser(user); err != nil {
		t.Fatalf("DeleteUser() error: %v", err)
	}

	conns, _ = b.LoadConnections(user)
	if len(conns) != 0 {
		t.Error("Connections should be deleted when user is deleted")
	}
}

func TestMemoryBackendMultipleUsers(t *testing.T) {
	t.Parallel()

	b := NewMemoryBackend()
	c := New(WithBackend(b))

	user1 := NewUser("user1@example.com", c)
	user2 := NewUser("user2@example.com", c)

	conn1 := NewIRCConnection("irc://irc.libera.chat:6697", user1)
	conn2 := NewIRCConnection("irc://irc.oftc.net:6697", user2)

	if err := b.SaveUser(user1); err != nil {
		t.Fatalf("SaveUser(user1) error: %v", err)
	}
	if err := b.SaveUser(user2); err != nil {
		t.Fatalf("SaveUser(user2) error: %v", err)
	}
	if err := b.SaveConnection(conn1); err != nil {
		t.Fatalf("SaveConnection(conn1) error: %v", err)
	}
	if err := b.SaveConnection(conn2); err != nil {
		t.Fatalf("SaveConnection(conn2) error: %v", err)
	}

	// Each user should only see their own connections
	conns1, err := b.LoadConnections(user1)
	if err != nil {
		t.Fatalf("LoadConnections(user1) error: %v", err)
	}
	conns2, err := b.LoadConnections(user2)
	if err != nil {
		t.Fatalf("LoadConnections(user2) error: %v", err)
	}

	if len(conns1) != 1 {
		t.Errorf("User1 connections = %d, want 1", len(conns1))
	}
	if len(conns2) != 1 {
		t.Errorf("User2 connections = %d, want 1", len(conns2))
	}

	if conns1[0].ID == conns2[0].ID {
		t.Error("Users should have different connections")
	}
}
