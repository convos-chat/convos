// Package auth implements pluggable authentication
package auth

import (
	"errors"

	"github.com/convos-chat/convos/pkg/core"
)

const authTypeLocal = "local"

var ErrInvalidCredentials = errors.New("invalid email or password")

// LocalAuthenticator implements password-based authentication using Argon2id.
type LocalAuthenticator struct {
	core *core.Core
}

// NewLocalAuthenticator creates a new local password authenticator.
func NewLocalAuthenticator(c *core.Core) *LocalAuthenticator {
	return &LocalAuthenticator{core: c}
}

// Authenticate validates email and password against stored user credentials.
func (a *LocalAuthenticator) Authenticate(req core.AuthRequest) (*core.AuthResult, error) {
	user := a.core.GetUser(req.Email)
	if user == nil {
		return nil, ErrInvalidCredentials
	}

	if !user.ValidatePassword(req.Password) {
		return nil, ErrInvalidCredentials
	}

	return &core.AuthResult{User: user}, nil
}

// Name returns the authenticator name.
func (a *LocalAuthenticator) Name() string {
	return authTypeLocal
}
