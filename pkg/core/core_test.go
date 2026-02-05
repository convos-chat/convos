package core

import (
	"testing"
)

const (
	testEmail   = "test@example.com"
	testChannel = "#test"
	roleAdmin   = "admin"
)

func TestNewCore(t *testing.T) {
	t.Parallel()

	c := New()

	if c.Home() == "" {
		t.Error("Home() should return a default path")
	}

	if c.Backend() == nil {
		t.Error("Backend() should return a default backend")
	}

	if c.Settings() == nil {
		t.Error("Settings() should return settings")
	}

	if c.Ready() {
		t.Error("Ready() should be false before Start()")
	}
}

func TestCoreWithOptions(t *testing.T) {
	t.Parallel()

	backend := NewMemoryBackend()
	c := New(
		WithHome("/tmp/convos-test"),
		WithBackend(backend),
	)

	if c.Home() != "/tmp/convos-test" {
		t.Errorf("Home() = %q, want %q", c.Home(), "/tmp/convos-test")
	}

	if c.Backend() != backend {
		t.Error("Backend() should return the provided backend")
	}
}

func TestCoreUserManagement(t *testing.T) {
	t.Parallel()

	c := New()

	// Create a user
	user, err := c.User(testEmail)
	if err != nil {
		t.Fatalf("User() error: %v", err)
	}

	if user.Email() != testEmail {
		t.Errorf("Email() = %q, want %q", user.Email(), testEmail)
	}

	// Get the same user again
	user2, err := c.User(testEmail)
	if err != nil {
		t.Fatalf("User() error: %v", err)
	}

	if user != user2 {
		t.Error("User() should return the same instance for the same email")
	}

	// GetUser should find existing user
	found := c.GetUser(testEmail)
	if found != user {
		t.Error("GetUser() should return the existing user")
	}

	// GetUser with non-existent email
	notFound := c.GetUser("nobody@example.com")
	if notFound != nil {
		t.Error("GetUser() should return nil for non-existent user")
	}

	// Users() should return all users
	users := c.Users()
	if len(users) != 1 {
		t.Errorf("Users() returned %d users, want 1", len(users))
	}
}

func TestCoreEmailNormalization(t *testing.T) {
	t.Parallel()

	c := New()

	user1, _ := c.User("Test@Example.COM")
	user2, _ := c.User(testEmail)
	user3, _ := c.User("  TEST@EXAMPLE.COM  ")

	if user1 != user2 || user2 != user3 {
		t.Error("User() should normalize email addresses")
	}

	if user1.Email() != testEmail {
		t.Errorf("Email() = %q, want normalized %q", user1.Email(), testEmail)
	}
}

func TestCoreStart(t *testing.T) {
	t.Parallel()

	c := New()

	if err := c.Start(); err != nil {
		t.Fatalf("Start() error: %v", err)
	}

	if !c.Ready() {
		t.Error("Ready() should be true after Start()")
	}

	// Start() again should be idempotent
	if err := c.Start(); err != nil {
		t.Fatalf("Start() second call error: %v", err)
	}
}

func TestCoreStartWithExistingUsers(t *testing.T) {
	t.Parallel()

	backend := NewMemoryBackend()

	// Pre-populate backend with a user
	backend.users["admin@example.com"] = UserData{
		Email:    "admin@example.com",
		Password: "$2a$10$abcdefghijklmnopqrstuv", // fake bcrypt hash
		Roles:    []string{},
		UID:      1,
	}

	c := New(WithBackend(backend))

	if err := c.Start(); err != nil {
		t.Fatalf("Start() error: %v", err)
	}

	// User should be loaded
	user := c.GetUser("admin@example.com")
	if user == nil {
		t.Fatal("User should be loaded from backend")
	}

	// First user without admin should get admin role
	if !user.HasRole(roleAdmin) {
		t.Error("First user should be given admin role")
	}
}

func TestCoreRemoveUser(t *testing.T) {
	t.Parallel()

	c := New()

	user, _ := c.User("delete@example.com")
	if user == nil {
		t.Fatal("Failed to create user")
	}

	if err := c.RemoveUser("delete@example.com"); err != nil {
		t.Fatalf("RemoveUser() error: %v", err)
	}

	if c.GetUser("delete@example.com") != nil {
		t.Error("User should be removed")
	}

	// Removing non-existent user should not error
	if err := c.RemoveUser("nobody@example.com"); err != nil {
		t.Errorf("RemoveUser() for non-existent user should not error: %v", err)
	}
}
