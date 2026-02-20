package auth

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/go-ldap/ldap/v3"
)

const authTypeLDAP = "ldap"

// LDAPAuthenticator implements authentication via LDAP bind.
// It attempts to bind to an LDAP server with the provided credentials,
// and optionally falls back to local password authentication on failure.
type LDAPAuthenticator struct {
	core      *core.Core
	url       string
	dnPattern string
	timeout   time.Duration
	fallback  core.Authenticator
}

// LDAPConfig contains configuration for LDAP authentication.
type LDAPConfig struct {
	URL       string `envconfig:"CONVOS_AUTH_LDAP_URL" default:"ldap://localhost:389"`
	DNPattern string `envconfig:"CONVOS_AUTH_LDAP_DN" default:"uid=%uid,dc=%domain,dc=%tld"`
	Timeout   int    `envconfig:"CONVOS_AUTH_LDAP_TIMEOUT" default:"10"`
	Fallback  bool   `envconfig:"CONVOS_AUTH_LDAP_FALLBACK" default:"true"`
}

// NewLDAPAuthenticator creates a new LDAP authenticator.
func NewLDAPAuthenticator(c *core.Core, cfg LDAPConfig) *LDAPAuthenticator {
	auth := &LDAPAuthenticator{
		core:      c,
		url:       cfg.URL,
		dnPattern: cfg.DNPattern,
		timeout:   time.Duration(cfg.Timeout) * time.Second,
	}

	// Enable local password fallback if configured
	if cfg.Fallback {
		auth.fallback = NewLocalAuthenticator(c)
	}

	return auth
}

// Authenticate attempts to bind to the LDAP server with the provided credentials.
// If the bind succeeds, the user is authenticated. If the user doesn't exist locally,
// they will be auto-created. On LDAP failure, falls back to local authentication if enabled.
func (a *LDAPAuthenticator) Authenticate(req core.AuthRequest) (*core.AuthResult, error) {
	// Build DN from email using pattern
	dn := a.buildDN(req.Email)

	// Dial LDAP server
	conn, err := ldap.DialURL(a.url)
	if err != nil {
		return a.tryFallback(req, fmt.Errorf("LDAP connection failed: %w", err))
	}
	defer conn.Close()

	// Set timeout
	conn.SetTimeout(a.timeout)

	// Attempt bind with credentials
	err = conn.Bind(dn, req.Password)
	if err != nil {
		// LDAP authentication failed - try fallback
		var ldapErr *ldap.Error
		if errors.As(err, &ldapErr) && ldapErr.ResultCode == ldap.LDAPResultInvalidCredentials {
			return a.tryFallback(req, ErrInvalidCredentials)
		}
		return a.tryFallback(req, fmt.Errorf("LDAP bind failed: %w", err))
	}

	// LDAP authentication successful - check if user exists locally
	if user := a.core.GetUser(req.Email); user != nil {
		return &core.AuthResult{User: user}, nil
	}

	// Auto-create user
	roles := a.core.RolesForNewUser()

	return &core.AuthResult{
		AutoCreate: true,
		Roles:      roles,
	}, nil
}

// buildDN constructs the LDAP distinguished name from the email using the configured pattern.
// It supports the following substitutions:
// - %uid: username part of email (before @)
// - %email: full email address
// - %domain: domain part (between @ and last .)
// - %tld: top-level domain (after last .)
func (a *LDAPAuthenticator) buildDN(email string) string {
	parts := strings.Split(email, "@")
	uid := parts[0]
	domain, tld := "", ""

	if len(parts) > 1 {
		domainParts := strings.Split(parts[1], ".")
		domain = domainParts[0]
		if len(domainParts) > 1 {
			tld = domainParts[len(domainParts)-1]
		}
	}

	dn := a.dnPattern
	dn = strings.ReplaceAll(dn, "%uid", uid)
	dn = strings.ReplaceAll(dn, "%email", email)
	dn = strings.ReplaceAll(dn, "%domain", domain)
	dn = strings.ReplaceAll(dn, "%tld", tld)
	return dn
}

// tryFallback attempts to authenticate using the fallback authenticator if enabled.
// If fallback is disabled, returns the LDAP error.
func (a *LDAPAuthenticator) tryFallback(req core.AuthRequest, ldapErr error) (*core.AuthResult, error) {
	if a.fallback != nil {
		return a.fallback.Authenticate(req)
	}
	return nil, ldapErr
}

// Name returns the authenticator name.
func (a *LDAPAuthenticator) Name() string {
	return authTypeLDAP
}
