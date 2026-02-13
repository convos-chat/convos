package auth

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
)

func TestLDAPAuthenticator_BuildDN(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name      string
		pattern   string
		email     string
		expectedDN string
	}{
		{
			name:      "Standard pattern",
			pattern:   "uid=%uid,dc=%domain,dc=%tld",
			email:     "john@example.com",
			expectedDN: "uid=john,dc=example,dc=com",
		},
		{
			name:      "Email in DN",
			pattern:   "mail=%email,ou=users,dc=company,dc=com",
			email:     "alice@example.org",
			expectedDN: "mail=alice@example.org,ou=users,dc=company,dc=com",
		},
		{
			name:      "Multiple substitutions",
			pattern:   "cn=%uid,ou=%domain,o=%tld",
			email:     "bob@subdomain.example.net",
			expectedDN: "cn=bob,ou=subdomain,o=net",
		},
		{
			name:      "No domain",
			pattern:   "uid=%uid,dc=%domain",
			email:     "user",
			expectedDN: "uid=user,dc=",
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			backend := core.NewMemoryBackend()
			c := core.New(core.WithBackend(backend))
			auth := NewLDAPAuthenticator(c, LDAPConfig{
				DNPattern: tt.pattern,
				Fallback:  false, // Disable fallback for these tests
			})

			dn := auth.buildDN(tt.email)
			if dn != tt.expectedDN {
				t.Errorf("buildDN(%q) = %q, want %q", tt.email, dn, tt.expectedDN)
			}
		})
	}
}

func TestLDAPAuthenticator_Fallback(t *testing.T) {
	t.Parallel()

	t.Run("FallbackEnabled_ValidLocalPassword", func(t *testing.T) {
		t.Parallel()
		backend := core.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))

		// Create user with local password
		user, err := c.User("test@example.com")
		if err != nil {
			t.Fatalf("Failed to create user: %v", err)
		}
		if err := user.SetPassword("testpassword"); err != nil {
			t.Fatalf("Failed to set password: %v", err)
		}
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to save user: %v", err)
		}

		auth := NewLDAPAuthenticator(c, LDAPConfig{
			URL:      "ldap://invalid.example.com:389", // Will fail to connect
			Fallback: true,
		})

		authReq := core.AuthRequest{
			Email:    "test@example.com",
			Password: "testpassword",
			Context:  context.Background(),
		}

		// LDAP will fail, but fallback should succeed
		result, err := auth.Authenticate(authReq)
		if err != nil {
			t.Fatalf("Expected fallback to succeed, got error: %v", err)
		}
		if result.User == nil {
			t.Fatal("Expected user in result")
		}
		if result.User.Email() != "test@example.com" {
			t.Errorf("Expected email test@example.com, got %s", result.User.Email())
		}
	})

	t.Run("FallbackDisabled", func(t *testing.T) {
		t.Parallel()
		backend := core.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))

		// Create user with local password
		user, err := c.User("test@example.com")
		if err != nil {
			t.Fatalf("Failed to create user: %v", err)
		}
		if err := user.SetPassword("testpassword"); err != nil {
			t.Fatalf("Failed to set password: %v", err)
		}
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to save user: %v", err)
		}

		auth := NewLDAPAuthenticator(c, LDAPConfig{
			URL:      "ldap://invalid.example.com:389", // Will fail to connect
			Fallback: false,
		})

		authReq := core.AuthRequest{
			Email:    "test@example.com",
			Password: "testpassword",
			Context:  context.Background(),
		}

		// LDAP will fail and fallback is disabled
		result, err := auth.Authenticate(authReq)
		if err == nil {
			t.Fatal("Expected authentication to fail with fallback disabled")
		}
		if result != nil {
			t.Error("Expected nil result on authentication failure")
		}
	})
}

func TestLDAPAuthenticator_Name(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	auth := NewLDAPAuthenticator(c, LDAPConfig{})

	if auth.Name() != "ldap" {
		t.Errorf("Expected authenticator name 'ldap', got %s", auth.Name())
	}
}

func TestLDAPAuthenticator_DefaultConfig(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))

	cfg := LDAPConfig{
		URL:       "ldap://localhost:389",
		DNPattern: "uid=%uid,dc=%domain,dc=%tld",
		Timeout:   10,
		Fallback:  true,
	}

	auth := NewLDAPAuthenticator(c, cfg)

	if auth.url != cfg.URL {
		t.Errorf("Expected URL %s, got %s", cfg.URL, auth.url)
	}
	if auth.dnPattern != cfg.DNPattern {
		t.Errorf("Expected DN pattern %s, got %s", cfg.DNPattern, auth.dnPattern)
	}
	if auth.fallback == nil {
		t.Error("Expected fallback to be enabled")
	}
}
