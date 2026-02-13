package core

import "context"

// AuthRequest contains credentials and context for authentication.
type AuthRequest struct {
	Email    string
	Password string
	Context  context.Context // For accessing HTTP request/headers
}

// AuthResult contains the outcome of authentication.
type AuthResult struct {
	User       *User
	AutoCreate bool     // Whether to auto-create user
	Roles      []string // Roles to assign on auto-creation
}

// Authenticator defines the authentication interface.
// Implementations can be found in pkg/auth/.
type Authenticator interface {
	// Authenticate validates credentials and returns result.
	// Returns AuthResult on success, error on failure.
	Authenticate(req AuthRequest) (*AuthResult, error)

	// Name returns authenticator name for logging.
	Name() string
}
