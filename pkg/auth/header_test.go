package auth

import (
	"context"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestHeaderAuthenticator(t *testing.T) {
	t.Parallel()

	t.Run("ExistingUser", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Authenticated-User"})

		// Create existing user
		user, err := c.User("test@example.com")
		if err != nil {
			t.Fatalf("Failed to create user: %v", err)
		}
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to save user: %v", err)
		}

		// Create request with header
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Authenticated-User", "test@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "test@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if result.User == nil {
			t.Fatal("Expected user in result")
		}
		if result.User.Email() != "test@example.com" {
			t.Errorf("Expected email test@example.com, got %s", result.User.Email())
		}
		if result.AutoCreate {
			t.Error("Expected AutoCreate to be false for existing user")
		}
	})

	t.Run("NewUser_FirstUser", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Authenticated-User"})

		// Create request with header
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Authenticated-User", "admin@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "admin@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if result.User != nil {
			t.Error("Expected nil user for auto-create scenario")
		}
		if !result.AutoCreate {
			t.Error("Expected AutoCreate to be true for new user")
		}
		if len(result.Roles) != 1 || result.Roles[0] != "admin" {
			t.Errorf("Expected admin role for first user, got %v", result.Roles)
		}
	})

	t.Run("NewUser_NotFirstUser", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Authenticated-User"})

		// Create first user
		firstUser, err := c.User("first@example.com")
		if err != nil {
			t.Fatalf("Failed to create first user: %v", err)
		}
		if err := firstUser.Save(); err != nil {
			t.Fatalf("Failed to save first user: %v", err)
		}

		// Create request with header for second user
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Authenticated-User", "second@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "second@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if !result.AutoCreate {
			t.Error("Expected AutoCreate to be true for new user")
		}
		if len(result.Roles) != 0 {
			t.Errorf("Expected no roles for non-first user, got %v", result.Roles)
		}
	})

	t.Run("AdminRequired_WrongUser", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{
			HeaderName: "X-Authenticated-User",
			AdminEmail: "admin@example.com",
		})

		// Try to register as non-admin when admin is required
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Authenticated-User", "user@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "user@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err == nil {
			t.Fatal("Expected authentication to fail when admin must register first")
		}
		if result != nil {
			t.Error("Expected nil result on authentication failure")
		}
	})

	t.Run("AdminRequired_CorrectUser", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{
			HeaderName: "X-Authenticated-User",
			AdminEmail: "admin@example.com",
		})

		// Register as admin when admin is required
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Authenticated-User", "admin@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "admin@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if !result.AutoCreate {
			t.Error("Expected AutoCreate to be true for admin user")
		}
		if len(result.Roles) != 1 || result.Roles[0] != "admin" {
			t.Errorf("Expected admin role, got %v", result.Roles)
		}
	})

	t.Run("MissingHeader", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Authenticated-User"})

		// Create request without header
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "test@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err == nil {
			t.Fatal("Expected authentication to fail with missing header")
		}
		if result != nil {
			t.Error("Expected nil result on authentication failure")
		}
	})

	t.Run("CustomHeaderName", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Remote-User"})

		// Create request with custom header
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", nil)
		req.Header.Set("X-Remote-User", "test@example.com")
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		authReq := core.AuthRequest{
			Email:   "test@example.com",
			Context: ctx,
		}

		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected successful authentication, got error: %v", err)
		}
		if !result.AutoCreate {
			t.Error("Expected AutoCreate to be true for new user")
		}
	})

	t.Run("AuthenticatorName", func(t *testing.T) {
		t.Parallel()
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		auth := NewHeaderAuthenticator(c, HeaderConfig{HeaderName: "X-Authenticated-User"})

		if auth.Name() != "header" {
			t.Errorf("Expected authenticator name 'header', got %s", auth.Name())
		}
	})
}
