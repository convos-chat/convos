package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
)

const (
	testEmail   = "test@example.com"
	testChannel = "#test"
	roleAdmin   = "admin"
)

func TestNewFileBackend(t *testing.T) {
	t.Parallel()

	b := NewFileBackend("/tmp/convos-test")
	if b == nil {
		t.Fatal("NewFileBackend() returned nil")
	}
	if b.Home() != "/tmp/convos-test" {
		t.Errorf("Home() = %q, want %q", b.Home(), "/tmp/convos-test")
	}
}

func TestFileBackendUserOperations(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, err := c.User(testEmail)
	if err != nil {
		t.Fatalf("Core.User() error: %v", err)
	}
	if err := user.SetPassword("secret"); err != nil {
		t.Fatalf("SetPassword() error: %v", err)
	}
	user.GiveRole(roleAdmin)
	user.SetUID(1)

	// Save user
	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}

	// Verify file exists
	userFile := filepath.Join(tmpDir, testEmail, "user.json")
	if _, err := os.Stat(userFile); os.IsNotExist(err) {
		t.Fatalf("user.json not created: %v", err)
	}

	// Verify uid is stored as string (Perl compatibility)
	raw, err := os.ReadFile(userFile)
	if err != nil {
		t.Fatalf("ReadFile() error: %v", err)
	}
	var rawJSON map[string]json.RawMessage
	if err := json.Unmarshal(raw, &rawJSON); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}
	uidRaw := string(rawJSON["uid"])
	if uidRaw != `"1"` {
		t.Errorf("uid in JSON = %s, want %q (string type for Perl compatibility)", uidRaw, "1")
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

	// Delete user
	if err := b.DeleteUser(user); err != nil {
		t.Fatalf("DeleteUser() error: %v", err)
	}

	// Verify directory removed
	if _, err := os.Stat(filepath.Join(tmpDir, testEmail)); !os.IsNotExist(err) {
		t.Error("User directory should be removed")
	}

	users, _ = b.LoadUsers()
	if len(users) != 0 {
		t.Errorf("LoadUsers() returned %d users after delete, want 0", len(users))
	}
}

func TestFileBackendConnectionOperations(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, _ := c.User(testEmail)

	// Create user directory first
	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}

	const testConnName = "Libera"
	conn := irc.NewConnection("irc://irc.libera.chat:6697", user)
	conn.SetName(testConnName)
	conn.SetOnConnectCommands([]string{"/join #test"})

	// Save connection
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Verify file exists
	connFile := filepath.Join(tmpDir, testEmail, conn.ID(), "connection.json")
	if _, err := os.Stat(connFile); os.IsNotExist(err) {
		t.Fatalf("connection.json not created: %v", err)
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
	if loaded.Name != testConnName {
		t.Errorf("Name = %q, want %q", loaded.Name, testConnName)
	}
	if loaded.State != "" {
		t.Error("State should not be loaded from file")
	}

	// Delete connection
	if err := b.DeleteConnection(conn); err != nil {
		t.Fatalf("DeleteConnection() error: %v", err)
	}

	conns, _ = b.LoadConnections(user)
	if len(conns) != 0 {
		t.Errorf("LoadConnections() returned %d after delete, want 0", len(conns))
	}
}

func TestFileBackendMessageOperations(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, _ := c.User(testEmail)
	conn := irc.NewConnection("irc://irc.libera.chat:6697", user)
	conv := core.NewConversation(testChannel, conn)

	// Create user and connection directories
	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Save messages (use times in the past to ensure they're within the query range)
	now := time.Now()
	baseTime := now.Add(-time.Hour)
	msgs := []core.Message{
		{From: "alice", Message: "Hello", Type: "private", Timestamp: baseTime.Unix()},
		{From: "bob", Message: "Hi there", Type: "private", Timestamp: baseTime.Add(time.Second).Unix()},
		{From: "alice", Message: "waves", Type: "action", Timestamp: baseTime.Add(2 * time.Second).Unix()},
	}

	for _, msg := range msgs {
		if err := b.SaveMessage(conv, msg); err != nil {
			t.Fatalf("SaveMessage() error: %v", err)
		}
	}

	// Perl-compatible log file path: YYYY/MM/convID.log per conversation.
	// Connection-level (server) messages use YYYY/MM.log (empty conversation ID).
	wantLogFile := filepath.Join(tmpDir, testEmail, conn.ID(),
		baseTime.UTC().Format("2006"), baseTime.UTC().Format("01"), testChannel+".log")
	if _, err := os.Stat(wantLogFile); os.IsNotExist(err) {
		t.Fatalf("Perl-compatible log file not created at %s", wantLogFile)
	}

	// Verify log format includes UTC offset field (Perl writes "TIMESTAMP 0 ...")
	raw, err := os.ReadFile(wantLogFile)
	if err != nil {
		t.Fatalf("ReadFile() error: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(string(raw)), "\n")
	if len(lines) != 3 {
		t.Fatalf("Expected 3 lines in log, got %d", len(lines))
	}
	// First line should be: "2026-02-07T09:05:00 0 <alice> Hello"
	if !strings.Contains(lines[0], " 0 <alice> Hello") {
		t.Errorf("Log line format wrong, got: %s\nwant pattern: TIMESTAMP 0 <alice> Hello", lines[0])
	}
	// Action line should be: "TIMESTAMP 0 * alice waves"
	if !strings.Contains(lines[2], " 0 * alice waves") {
		t.Errorf("Action log line format wrong, got: %s\nwant pattern: TIMESTAMP 0 * alice waves", lines[2])
	}

	// Load messages with explicit time range that includes all messages
	result, err := b.LoadMessages(conv, core.MessageQuery{
		Limit:  10,
		Before: now.Add(time.Hour).Format(time.RFC3339),       // 1 hour in future
		After:  baseTime.Add(-time.Hour).Format(time.RFC3339), // 1 hour before first message
	})
	if err != nil {
		t.Fatalf("LoadMessages() error: %v", err)
	}

	if len(result.Messages) != 3 {
		t.Errorf("LoadMessages() returned %d messages, want 3", len(result.Messages))
	}

	// Check message types are preserved
	found := make(map[core.MessageType]bool)
	for _, msg := range result.Messages {
		found[msg.Type] = true
	}
	if !found[core.MessageTypePrivate] || !found[core.MessageTypeAction] {
		t.Errorf("Message types not preserved: %v", result.Messages)
	}

	// Delete messages
	if err := b.DeleteMessages(conv); err != nil {
		t.Fatalf("DeleteMessages() error: %v", err)
	}

	result, _ = b.LoadMessages(conv, core.MessageQuery{Limit: 10})
	if len(result.Messages) != 0 {
		t.Errorf("LoadMessages() after delete returned %d, want 0", len(result.Messages))
	}
}

// TestFileBackendLoadMessagesReturnsNewest verifies that when there are more
// messages than the limit, the most recent messages are returned (not the oldest).
// This was the core bug: readLogFile read forward and stopped at limit, returning
// the oldest messages from the file instead of the newest.
func TestFileBackendLoadMessagesReturnsNewest(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, _ := c.User(testEmail)
	conn := irc.NewConnection("irc://localhost:6667", user)
	conv := core.NewConversation("", conn) // server messages (empty conv ID)

	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Write 100 messages to the current month's log file
	now := time.Now().UTC()
	logDir := filepath.Join(tmpDir, testEmail, conn.ID(), now.Format("2006"))
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}
	logFile := filepath.Join(logDir, now.Format("01")+".log")

	var lines []string
	baseTime := now.Add(-100 * time.Minute)
	for i := 0; i < 100; i++ {
		ts := baseTime.Add(time.Duration(i) * time.Minute)
		lines = append(lines, fmt.Sprintf("%s 0 -!- Server message %d", ts.Format("2006-01-02T15:04:05"), i))
	}
	if err := os.WriteFile(logFile, []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatalf("WriteFile() error: %v", err)
	}

	// Default query (no params) should return the NEWEST messages
	result, err := b.LoadMessages(conv, core.MessageQuery{Limit: 20})
	if err != nil {
		t.Fatalf("LoadMessages() error: %v", err)
	}

	if len(result.Messages) != 20 {
		t.Fatalf("LoadMessages() returned %d messages, want 20", len(result.Messages))
	}

	// The last message in the result should be close to "Server message 99" (newest)
	lastMsg := result.Messages[len(result.Messages)-1]
	if !strings.Contains(lastMsg.Message, "Server message 99") {
		t.Errorf("Last message = %q, want it to contain 'Server message 99'", lastMsg.Message)
	}

	// The first message should be "Server message 80" (20 newest = 80-99)
	firstMsg := result.Messages[0]
	if !strings.Contains(firstMsg.Message, "Server message 80") {
		t.Errorf("First message = %q, want it to contain 'Server message 80'", firstMsg.Message)
	}

	// End should be false since we didn't return all messages
	if result.End {
		t.Error("End should be false when there are more messages")
	}

	// Query with "after" should return oldest-first (forward direction)
	afterTime := baseTime.Add(-time.Minute)
	result, err = b.LoadMessages(conv, core.MessageQuery{
		Limit: 20,
		After: afterTime.Format(time.RFC3339),
	})
	if err != nil {
		t.Fatalf("LoadMessages(after) error: %v", err)
	}

	if len(result.Messages) != 20 {
		t.Fatalf("LoadMessages(after) returned %d messages, want 20", len(result.Messages))
	}

	// Forward direction: first message should be the oldest
	firstMsg = result.Messages[0]
	if !strings.Contains(firstMsg.Message, "Server message 0") {
		t.Errorf("First message (forward) = %q, want it to contain 'Server message 0'", firstMsg.Message)
	}

	lastMsg = result.Messages[len(result.Messages)-1]
	if !strings.Contains(lastMsg.Message, "Server message 19") {
		t.Errorf("Last message (forward) = %q, want it to contain 'Server message 19'", lastMsg.Message)
	}
}

// TestFileBackendPerlLogCompat verifies that Go can read Perl-format log files.
func TestFileBackendPerlLogCompat(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, _ := c.User(testEmail)
	conn := irc.NewConnection("irc://localhost:6667", user)
	conv := core.NewConversation(testChannel, conn)

	if err := b.SaveUser(user); err != nil {
		t.Fatalf("SaveUser() error: %v", err)
	}
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection() error: %v", err)
	}

	// Write a Perl-format log file directly (per-conversation: YYYY/MM/convID.log)
	logDir := filepath.Join(tmpDir, testEmail, conn.ID(), "2026", "02")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}
	logFile := filepath.Join(logDir, testChannel+".log")
	perlLog := strings.Join([]string{
		"2026-02-07T09:09:36 0 -irc-localhost- Connecting to localhost.",
		"2026-02-07T09:09:36 0 -irc-localhost- Connected to localhost.",
		"2026-02-07T09:09:36 0 <example.com> Welcome to the testnetwork IRC Network perluser",
		"2026-02-07T09:09:36 0 * perluser waves",
		"2026-02-07T09:09:36 0 -!- perluser has quit",
	}, "\n") + "\n"
	if err := os.WriteFile(logFile, []byte(perlLog), 0o600); err != nil {
		t.Fatalf("WriteFile() error: %v", err)
	}

	// Load messages — Go must be able to read Perl's format
	result, err := b.LoadMessages(conv, core.MessageQuery{
		Limit:  100,
		Before: "2026-02-08T00:00:00Z",
		After:  "2026-02-07T00:00:00Z",
	})
	if err != nil {
		t.Fatalf("LoadMessages() error: %v", err)
	}

	if len(result.Messages) != 5 {
		t.Fatalf("LoadMessages() returned %d messages, want 5", len(result.Messages))
	}

	// Verify parsed message types and fields
	tests := []struct {
		wantType core.MessageType
		wantFrom string
		wantMsg  string
	}{
		{core.MessageTypeNotice, "irc-localhost", "Connecting to localhost."},
		{core.MessageTypeNotice, "irc-localhost", "Connected to localhost."},
		{core.MessageTypePrivate, "example.com", "Welcome to the testnetwork IRC Network perluser"},
		{core.MessageTypeAction, "perluser", "waves"},
		{core.MessageTypeNotice, "", "perluser has quit"},
	}

	for i, tt := range tests {
		msg := result.Messages[i]
		if msg.Type != tt.wantType {
			t.Errorf("msg[%d].Type = %q, want %q", i, msg.Type, tt.wantType)
		}
		if msg.From != tt.wantFrom {
			t.Errorf("msg[%d].From = %q, want %q", i, msg.From, tt.wantFrom)
		}
		if msg.Message != tt.wantMsg {
			t.Errorf("msg[%d].Message = %q, want %q", i, msg.Message, tt.wantMsg)
		}
	}
}

func TestFileBackendMessageFormats(t *testing.T) {
	t.Parallel()

	b := NewFileBackend("/tmp")

	tests := []struct {
		input    string
		wantType core.MessageType
		wantFrom string
		wantMsg  string
	}{
		{"<alice> Hello world", core.MessageTypePrivate, "alice", "Hello world"},
		{"-bob- This is a notice", core.MessageTypeNotice, "bob", "This is a notice"},
		{"* charlie waves", core.MessageTypeAction, "charlie", "waves"},
		{"-!- User has quit", core.MessageTypeNotice, "", "User has quit"},
		{"Some other text", core.MessageTypeNotice, "", "Some other text"},
	}

	for _, tt := range tests {
		msg := b.parseMessageLine(tt.input)
		if msg.Type != tt.wantType {
			t.Errorf("parseMessageLine(%q).Type = %q, want %q", tt.input, msg.Type, tt.wantType)
		}
		if msg.From != tt.wantFrom {
			t.Errorf("parseMessageLine(%q).From = %q, want %q", tt.input, msg.From, tt.wantFrom)
		}
		if msg.Message != tt.wantMsg {
			t.Errorf("parseMessageLine(%q).Message = %q, want %q", tt.input, msg.Message, tt.wantMsg)
		}
	}
}

func TestFileBackendLoadUsersEmpty(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)

	users, err := b.LoadUsers()
	if err != nil {
		t.Fatalf("LoadUsers() error: %v", err)
	}
	if len(users) != 0 {
		t.Errorf("LoadUsers() = %d, want 0", len(users))
	}
}

func TestFileBackendLoadUsersNonExistent(t *testing.T) {
	t.Parallel()

	b := NewFileBackend("/nonexistent/path")

	users, err := b.LoadUsers()
	if err != nil {
		t.Fatalf("LoadUsers() error: %v", err)
	}
	if len(users) != 0 {
		t.Errorf("LoadUsers() = %d, want 0", len(users))
	}
}

func TestFileBackendNotifications(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b), core.WithHome(tmpDir))
	user, _ := c.User(testEmail)

	// No notifications file - should return empty
	result, err := b.LoadNotifications(user, core.MessageQuery{Limit: 10})
	if err != nil {
		t.Fatalf("LoadNotifications() error: %v", err)
	}
	if len(result.Notifications) != 0 {
		t.Errorf("LoadNotifications() = %d, want 0", len(result.Notifications))
	}
}
