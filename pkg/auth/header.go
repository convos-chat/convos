package auth

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/convos-chat/convos/pkg/core"
)

const authTypeHeader = "header"

var (
	ErrNoHTTPRequest = errors.New("no HTTP request in context")
	ErrHeaderMissing = errors.New("authentication header not found")
	ErrAdminRequired = errors.New("admin must register first")
)

// HeaderAuthenticator implements authentication via HTTP headers set by a reverse proxy.
// This is commonly used with nginx, Apache, or other reverse proxies that handle
// authentication and pass the authenticated user's email via a header.
type HeaderAuthenticator struct {
	core       *core.Core
	headerName string
	adminEmail string
}

// HeaderConfig contains configuration for header-based authentication.
type HeaderConfig struct {
	HeaderName string `envconfig:"CONVOS_AUTH_HEADER" default:"X-Authenticated-User"`
	AdminEmail string `envconfig:"CONVOS_ADMIN"`
}

// NewHeaderAuthenticator creates a new header-based authenticator.
func NewHeaderAuthenticator(c *core.Core, cfg HeaderConfig) *HeaderAuthenticator {
	return &HeaderAuthenticator{
		core:       c,
		headerName: cfg.HeaderName,
		adminEmail: cfg.AdminEmail,
	}
}

// Authenticate reads the user email from the configured HTTP header and validates it.
// If the user doesn't exist, it will be auto-created.
func (a *HeaderAuthenticator) Authenticate(req core.AuthRequest) (*core.AuthResult, error) {
	// Extract HTTP request from context
	r, ok := req.Context.Value(core.CtxKeyRequest).(*http.Request)
	if !ok {
		return nil, ErrNoHTTPRequest
	}

	email := r.Header.Get(a.headerName)
	if email == "" {
		return nil, fmt.Errorf("%w: %s", ErrHeaderMissing, a.headerName)
	}

	if user := a.core.GetUser(email); user != nil {
		return &core.AuthResult{User: user}, nil
	}

	// Auto-registration: enforce admin-first policy if configured
	nUsers := len(a.core.Users())
	if nUsers == 0 {
		if a.adminEmail != "" && email != a.adminEmail {
			return nil, fmt.Errorf("%w: %s", ErrAdminRequired, a.adminEmail)
		}
	}
	roles := a.core.RolesForNewUser()

	return &core.AuthResult{
		AutoCreate: true,
		Roles:      roles,
	}, nil
}

// Name returns the authenticator name.
func (a *HeaderAuthenticator) Name() string {
	return authTypeHeader
}
