package core_test

import (
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestNewUser(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	if user.Email() != testEmail {
		t.Errorf("Email() = %q, want %q", user.Email(), testEmail)
	}

	if user.ID() != testEmail {
		t.Errorf("ID() = %q, want %q", user.ID(), testEmail)
	}

	if user.Core() != c {
		t.Error("Core() should return the parent core")
	}

	if user.RemoteAddress() != "127.0.0.1" {
		t.Errorf("RemoteAddress() = %q, want %q", user.RemoteAddress(), "127.0.0.1")
	}

	if user.Registered().IsZero() {
		t.Error("Registered() should be set")
	}
}

func TestUserPassword(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	// Initially no password
	if user.Password() != "" {
		t.Error("Password() should be empty initially")
	}

	if user.ValidatePassword("anything") {
		t.Error("ValidatePassword() should fail with no password set")
	}

	// Set password
	if err := user.SetPassword("secret123"); err != nil {
		t.Fatalf("SetPassword() error: %v", err)
	}

	if user.Password() == "" {
		t.Error("Password() should be set after SetPassword()")
	}

	if user.Password() == "secret123" {
		t.Error("Password() should be hashed, not plain text")
	}

	// Validate correct password
	if !user.ValidatePassword("secret123") {
		t.Error("ValidatePassword() should succeed with correct password")
	}

	// Validate wrong password
	if user.ValidatePassword("wrongpassword") {
		t.Error("ValidatePassword() should fail with wrong password")
	}

	// Validate empty password
	if user.ValidatePassword("") {
		t.Error("ValidatePassword() should fail with empty password")
	}
}

func TestUserRoles(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	// Initially no roles
	if len(user.Roles()) != 0 {
		t.Errorf("Roles() = %v, want empty", user.Roles())
	}

	if user.HasRole(roleAdmin) {
		t.Error("HasRole(admin) should be false initially")
	}

	// Give role
	user.GiveRole(roleAdmin)
	if !user.HasRole(roleAdmin) {
		t.Error("HasRole(admin) should be true after GiveRole")
	}

	// Give same role again (idempotent)
	user.GiveRole(roleAdmin)
	roles := user.Roles()
	count := 0
	for _, r := range roles {
		if r == roleAdmin {
			count++
		}
	}
	if count != 1 {
		t.Errorf("admin role appears %d times, want 1", count)
	}

	// Give another role
	user.GiveRole("moderator")
	if !user.HasRole("moderator") {
		t.Error("HasRole(moderator) should be true")
	}

	// Roles should be sorted
	roles = user.Roles()
	if len(roles) != 2 || roles[0] != roleAdmin || roles[1] != "moderator" {
		t.Errorf("Roles() = %v, want [admin moderator]", roles)
	}

	// Take role
	user.TakeRole(roleAdmin)
	if user.HasRole(roleAdmin) {
		t.Error("HasRole(admin) should be false after TakeRole")
	}

	if !user.HasRole("moderator") {
		t.Error("HasRole(moderator) should still be true")
	}
}

func TestUserHighlightKeywords(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	// Initially empty
	if len(user.HighlightKeywords()) != 0 {
		t.Error("HighlightKeywords() should be empty initially")
	}

	// Set keywords
	user.SetHighlightKeywords([]string{"urgent", "important"})
	keywords := user.HighlightKeywords()

	if len(keywords) != 2 {
		t.Errorf("HighlightKeywords() = %v, want 2 items", keywords)
	}
}

func TestUserConnections(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	// Initially no connections
	if len(user.Connections()) != 0 {
		t.Error("Connections() should be empty initially")
	}

	// Add connection
	conn := newTestConnection("irc://irc.libera.chat:6697", user)
	user.AddConnection(conn)

	conns := user.Connections()
	if len(conns) != 1 {
		t.Errorf("Connections() = %d, want 1", len(conns))
	}

	// Get connection by ID
	found := user.GetConnection(conn.ID())
	if found != conn {
		t.Error("GetConnection() should return the added connection")
	}

	// Get non-existent connection
	notFound := user.GetConnection("nonexistent")
	if notFound != nil {
		t.Error("GetConnection() should return nil for non-existent ID")
	}

	// Remove connection
	if err := user.RemoveConnection(conn.ID()); err != nil {
		t.Fatalf("RemoveConnection() error: %v", err)
	}

	if len(user.Connections()) != 0 {
		t.Error("Connection should be removed")
	}
}

func TestUserUnread(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)

	if user.Unread() != 0 {
		t.Errorf("Unread() = %d, want 0", user.Unread())
	}

	user.SetUnread(5)
	if user.Unread() != 5 {
		t.Errorf("Unread() = %d, want 5", user.Unread())
	}
}

func TestUserToData(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser(testEmail, c)
	if err := user.SetPassword("secret"); err != nil {
		t.Fatalf("SetPassword() error: %v", err)
	}
	user.GiveRole(roleAdmin)
	user.SetRemoteAddress("192.168.1.1")
	user.SetHighlightKeywords([]string{"alert"})
	user.SetUnread(3)
	user.SetUID(42)

	// Without password
	data := user.ToData(false)
	if data.Email != testEmail {
		t.Errorf("Email = %q, want %q", data.Email, testEmail)
	}
	if data.Password != "" {
		t.Error("Password should be omitted when includePassword is false")
	}
	if len(data.Roles) != 1 || data.Roles[0] != roleAdmin {
		t.Errorf("Roles = %v, want [admin]", data.Roles)
	}
	if data.RemoteAddress != "192.168.1.1" {
		t.Errorf("RemoteAddress = %q, want %q", data.RemoteAddress, "192.168.1.1")
	}
	if data.Unread != 3 {
		t.Errorf("Unread = %d, want 3", data.Unread)
	}
	if data.UID != 42 {
		t.Errorf("UID = %d, want 42", data.UID)
	}

	// With password
	dataWithPass := user.ToData(true)
	if dataWithPass.Password == "" {
		t.Error("Password should be included when includePassword is true")
	}
}

func TestUserRegisteredTime(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	before := time.Now().UTC().Truncate(time.Second)
	user := core.NewUser(testEmail, c)
	after := time.Now().UTC().Truncate(time.Second)

	reg := user.Registered()
	if reg.Before(before) || reg.After(after) {
		t.Errorf("Registered() = %v, should be between %v and %v", reg, before, after)
	}
	if reg.Location() != time.UTC {
		t.Errorf("Registered() should be in UTC, got %v", reg.Location())
	}
	if reg.Nanosecond() != 0 {
		t.Errorf("Registered() should have no sub-second precision, got %v", reg)
	}
}
