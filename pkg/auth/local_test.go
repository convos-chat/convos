package auth

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

const testEmail = "test@example.com"

func TestLocalAuthenticator(t *testing.T) {
	t.Parallel()
	c := test.NewTestCore()
	auth := NewLocalAuthenticator(c)

	// Create test user
	user, err := c.User(testEmail)
	if err != nil {
		t.Fatalf("Failed to create user: %v", err)
	}
	if err := user.SetPassword("testpassword"); err != nil {
		t.Fatalf("Failed to set password: %v", err)
	}
	if err := user.Save(); err != nil {
		t.Fatalf("Failed to save user: %v", err)
	}

	t.Run("ValidCredentials", func(t *testing.T) {
		t.Parallel()
		req := core.AuthRequest{
			Email:    testEmail,
			Password: "testpassword",
			Context:  context.Background(),
		}

		result, err := auth.Authenticate(req)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if result.User == nil {
			t.Fatal("Expected user in result")
		}
		if result.User.Email() != testEmail {
			t.Errorf("Expected email test@example.com, got %s", result.User.Email())
		}
		if result.AutoCreate {
			t.Error("Expected AutoCreate to be false for existing user")
		}
	})

	t.Run("InvalidPassword", func(t *testing.T) {
		t.Parallel()
		req := core.AuthRequest{
			Email:    testEmail,
			Password: "wrongpassword",
			Context:  context.Background(),
		}

		result, err := auth.Authenticate(req)
		if err == nil {
			t.Fatal("Expected authentication to fail with invalid password")
		}
		if result != nil {
			t.Error("Expected nil result on authentication failure")
		}
		if err.Error() != "invalid email or password" {
			t.Errorf("Expected error message 'invalid email or password', got: %v", err)
		}
	})

	t.Run("NonexistentUser", func(t *testing.T) {
		t.Parallel()
		req := core.AuthRequest{
			Email:    "nonexistent@example.com",
			Password: "anypassword",
			Context:  context.Background(),
		}

		result, err := auth.Authenticate(req)
		if err == nil {
			t.Fatal("Expected authentication to fail for nonexistent user")
		}
		if result != nil {
			t.Error("Expected nil result on authentication failure")
		}
	})

	t.Run("AuthenticatorName", func(t *testing.T) {
		t.Parallel()
		if auth.Name() != "local" {
			t.Errorf("Expected authenticator name 'local', got %s", auth.Name())
		}
	})
}
