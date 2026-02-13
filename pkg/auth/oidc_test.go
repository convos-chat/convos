package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"golang.org/x/oauth2"
)

const oidcProviderName = "oidc"

func TestStateStore(t *testing.T) {
	t.Parallel()
	store := newStateStore()

	t.Run("generate and validate state", func(t *testing.T) {
		t.Parallel()
		nonce := "test-nonce"
		state, err := store.generate(nonce)
		if err != nil {
			t.Fatalf("failed to generate state: %v", err)
		}

		if state == "" {
			t.Fatal("expected non-empty state")
		}

		retrievedNonce, ok := store.validate(state)
		if !ok {
			t.Fatal("expected state to be valid")
		}
		if retrievedNonce != nonce {
			t.Fatalf("expected nonce %q, got %q", nonce, retrievedNonce)
		}

		// State should be consumed after validation
		if _, ok := store.validate(state); ok {
			t.Fatal("expected state to be invalid after consumption")
		}
	})

	t.Run("invalid state", func(t *testing.T) {
		t.Parallel()
		if _, ok := store.validate("invalid-state"); ok {
			t.Fatal("expected invalid state to be rejected")
		}
	})

	t.Run("expired state", func(t *testing.T) {
		t.Parallel()
		state, err := store.generate("nonce")
		if err != nil {
			t.Fatalf("failed to generate state: %v", err)
		}

		// Manually expire the state
		store.mu.Lock()
		store.states[state] = stateData{
			nonce:  "nonce",
			expiry: time.Now().Add(-1 * time.Hour),
		}
		store.mu.Unlock()

		if _, ok := store.validate(state); ok {
			t.Fatal("expected expired state to be rejected")
		}
	})

	t.Run("cleanup expired states", func(t *testing.T) {
		t.Parallel()
		state1, _ := store.generate("nonce1")
		state2, _ := store.generate("nonce2")

		// Expire state1
		store.mu.Lock()
		store.states[state1] = stateData{
			nonce:  "nonce1",
			expiry: time.Now().Add(-1 * time.Hour),
		}
		store.mu.Unlock()

		store.cleanup()

		store.mu.RLock()
		_, exists1 := store.states[state1]
		_, exists2 := store.states[state2]
		store.mu.RUnlock()

		if exists1 {
			t.Fatal("expected expired state1 to be removed")
		}
		if !exists2 {
			t.Fatal("expected valid state2 to remain")
		}
	})
}

func TestNewOIDCAuthenticator_Validation(t *testing.T) {
	t.Parallel()
	testCases := []struct {
		name        string
		config      OIDCConfig
		expectError bool
		errorMsg    string
	}{
		{
			name: "missing issuer URL",
			config: OIDCConfig{
				ClientID:     "test-client",
				ClientSecret: "test-secret",
			},
			expectError: true,
			errorMsg:    "OIDC issuer URL is required",
		},
		{
			name: "missing client ID",
			config: OIDCConfig{
				IssuerURL:    "https://accounts.google.com",
				ClientSecret: "test-secret",
			},
			expectError: true,
			errorMsg:    "OIDC client ID is required",
		},
		{
			name: "missing client secret",
			config: OIDCConfig{
				IssuerURL: "https://accounts.google.com",
				ClientID:  "test-client",
			},
			expectError: true,
			errorMsg:    "OIDC client secret is required",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := NewOIDCAuthenticator(nil, tc.config)
			if tc.expectError {
				if err == nil {
					t.Fatalf("expected error %q, got nil", tc.errorMsg)
				} else if err.Error() != tc.errorMsg {
					t.Fatalf("expected error %q, got %q", tc.errorMsg, err.Error())
				}
			} else if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
		})
	}
}

func TestOIDCAuthenticator_Name(t *testing.T) {
	t.Parallel()
	auth := &OIDCAuthenticator{}
	if auth.Name() != oidcProviderName {
		t.Fatalf("expected name %q, got %q", oidcProviderName, auth.Name())
	}
}

func TestOIDCAuthenticator_Authenticate(t *testing.T) {
	t.Parallel()
	auth := &OIDCAuthenticator{}
	_, err := auth.Authenticate(core.AuthRequest{})
	if err == nil {
		t.Fatal("expected error when calling Authenticate directly on OIDC authenticator")
	}
}

func TestOIDCAuthenticator_GetAuthCodeURL(t *testing.T) {
	t.Parallel()
	// This is a minimal test since we can't easily set up a real OIDC provider
	auth := &OIDCAuthenticator{
		oauth2Config: oauth2.Config{
			ClientID:    "test-client",
			RedirectURL: "http://localhost:3000/callback",
		},
	}

	state := "test-state"
	nonce := "test-nonce"

	url := auth.GetAuthCodeURL(state, nonce)
	if url == "" {
		t.Fatal("expected non-empty auth code URL")
	}

	// Basic validation that it contains expected parameters
	if !contains(url, "client_id=test-client") {
		t.Error("expected URL to contain client_id parameter")
	}
	if !contains(url, "redirect_uri=") {
		t.Error("expected URL to contain redirect_uri parameter")
	}
	if !contains(url, "state=test-state") {
		t.Error("expected URL to contain state parameter")
	}
}

func TestOIDCAuthenticator_HandleCallback_ValidationErrors(t *testing.T) {
	t.Parallel()
	auth := &OIDCAuthenticator{
		states: newStateStore(),
	}

	ctx := context.Background()

	t.Run("invalid state", func(t *testing.T) {
		t.Parallel()
		_, err := auth.HandleCallback(ctx, "some-code", "invalid-state")
		if !errors.Is(err, ErrInvalidState) {
			t.Fatalf("expected ErrInvalidState, got %v", err)
		}
	})

	t.Run("missing code", func(t *testing.T) {
		t.Parallel()
		state, _ := auth.states.generate("nonce")
		_, err := auth.HandleCallback(ctx, "", state)
		if !errors.Is(err, ErrMissingCode) {
			t.Fatalf("expected ErrMissingCode, got %v", err)
		}
	})
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
