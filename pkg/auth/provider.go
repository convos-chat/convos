package auth

import (
	"errors"
	"fmt"

	"github.com/convos-chat/convos/pkg/core"
)

var ErrUnknownProvider = errors.New("unknown auth provider")

// ProviderConfig contains configuration for all authentication providers.
type ProviderConfig struct {
	Provider string       `envconfig:"CONVOS_AUTH_PROVIDER" default:"local"`
	Header   HeaderConfig // Configuration for header-based authentication
	LDAP     LDAPConfig   // Configuration for LDAP authentication
	// Future: OIDC config will be added here
}

// NewAuthenticator creates an authenticator based on the provider configuration.
func NewAuthenticator(c *core.Core, cfg ProviderConfig) (core.Authenticator, error) {
	switch cfg.Provider {
	case "local", "":
		return NewLocalAuthenticator(c), nil

	case "header":
		return NewHeaderAuthenticator(c, cfg.Header), nil

	case "ldap":
		return NewLDAPAuthenticator(c, cfg.LDAP), nil

	default:
		return nil, fmt.Errorf("%w: %s", ErrUnknownProvider, cfg.Provider)
	}
}
