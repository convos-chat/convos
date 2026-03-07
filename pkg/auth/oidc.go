package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

var (
	ErrInvalidState        = errors.New("invalid state parameter")
	ErrMissingCode         = errors.New("missing authorization code")
	ErrTokenExchange       = errors.New("failed to exchange authorization code")
	ErrTokenVerification   = errors.New("failed to verify ID token")
	ErrEmailClaimMissing   = errors.New("email claim missing from ID token")
	ErrMissingIssuerURL    = errors.New("OIDC issuer URL is required")
	ErrMissingClientID     = errors.New("OIDC client ID is required")
	ErrMissingClientSecret = errors.New("OIDC client secret is required")
	ErrNoIDToken           = errors.New("no id_token in token response")
	ErrOAuth2FlowRequired  = errors.New("OIDC authentication requires OAuth2 flow via InitiateLogin/HandleCallback")
	ErrInvalidNonce        = errors.New("invalid id_token nonce")
	ErrEmailNotVerified    = errors.New("email not verified by provider")
)

// OIDCConfig contains configuration for OIDC authentication.
type OIDCConfig struct {
	IssuerURL    string `envconfig:"CONVOS_AUTH_OIDC_ISSUER"`
	ClientID     string `envconfig:"CONVOS_AUTH_OIDC_CLIENT_ID"`
	ClientSecret string `envconfig:"CONVOS_AUTH_OIDC_CLIENT_SECRET"`
	Scopes       string `envconfig:"CONVOS_AUTH_OIDC_SCOPES" default:"openid,profile,email"`
}

// OIDCAuthenticator implements OIDC/OAuth2 authentication.
type OIDCAuthenticator struct {
	core         *core.Core
	provider     *oidc.Provider
	oauth2Config oauth2.Config
	verifier     *oidc.IDTokenVerifier
	states       *stateStore
}

// stateStore manages CSRF state tokens for OAuth2 flow.
type stateStore struct {
	mu     sync.RWMutex
	states map[string]stateData
}

type stateData struct {
	nonce  string
	expiry time.Time
}

func newStateStore() *stateStore {
	return &stateStore{
		states: make(map[string]stateData),
	}
}

// generate creates a new random state token and stores it with the nonce.
func (s *stateStore) generate(nonce string) (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	state := hex.EncodeToString(b)

	s.mu.Lock()
	s.states[state] = stateData{
		nonce:  nonce,
		expiry: time.Now().Add(10 * time.Minute),
	}
	s.mu.Unlock()

	return state, nil
}

// validate checks if a state token is valid, removes it, and returns the stored nonce.
func (s *stateStore) validate(state string) (string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	data, ok := s.states[state]
	if !ok {
		return "", false
	}

	delete(s.states, state)
	if time.Now().After(data.expiry) {
		return "", false
	}

	return data.nonce, true
}

// cleanup removes expired state tokens.
func (s *stateStore) cleanup() {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	for state, data := range s.states {
		if now.After(data.expiry) {
			delete(s.states, state)
		}
	}
}

// NewOIDCAuthenticator creates a new OIDC authenticator.
func NewOIDCAuthenticator(c *core.Core, cfg OIDCConfig) (*OIDCAuthenticator, error) {
	if cfg.IssuerURL == "" {
		return nil, ErrMissingIssuerURL
	}
	if cfg.ClientID == "" {
		return nil, ErrMissingClientID
	}
	if cfg.ClientSecret == "" {
		return nil, ErrMissingClientSecret
	}

	ctx := context.Background()
	provider, err := oidc.NewProvider(ctx, cfg.IssuerURL)
	if err != nil {
		return nil, fmt.Errorf("failed to create OIDC provider: %w", err)
	}

	// Parse scopes from comma-separated string
	scopes := []string{oidc.ScopeOpenID}
	if cfg.Scopes != "" {
		for i, s := range []string{"profile", "email"} {
			if i == 0 || cfg.Scopes != "openid" {
				scopes = append(scopes, s)
			}
		}
	}

	auth := &OIDCAuthenticator{
		core:     c,
		provider: provider,
		oauth2Config: oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			Endpoint:     provider.Endpoint(),
			Scopes:       scopes,
		},
		verifier: provider.Verifier(&oidc.Config{ClientID: cfg.ClientID}),
		states:   newStateStore(),
	}

	go auth.cleanupLoop()

	return auth, nil
}

// cleanupLoop periodically removes expired state tokens.
func (a *OIDCAuthenticator) cleanupLoop() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		a.states.cleanup()
	}
}

// Authenticate  stubbed for interface compat
func (a *OIDCAuthenticator) Authenticate(req core.AuthRequest) (*core.AuthResult, error) {
	return nil, ErrOAuth2FlowRequired
}

// Name returns the authenticator name for logging.
func (a *OIDCAuthenticator) Name() string {
	return "oidc"
}

// getOAuth2Config returns the OAuth2 configuration with the correct redirect URL.
func (a *OIDCAuthenticator) getOAuth2Config() *oauth2.Config {
	cfg := a.oauth2Config

	// If core is not available (e.g. testing), return config without redirect URL
	// or with a placeholder if needed.
	if a.core == nil {
		return &cfg
	}

	redirectPath, _ := url.Parse("auth/oidc/callback")
	baseURL := a.core.Settings.BaseURL()
	cfg.RedirectURL = baseURL.ResolveReference(redirectPath).String()

	return &cfg
}

// InitiateLogin starts the OIDC login flow by redirecting to the provider.
func (a *OIDCAuthenticator) InitiateLogin(w http.ResponseWriter, r *http.Request) error {
	// Generate nonce for replay attack prevention
	nonceBytes := make([]byte, 32)
	if _, err := rand.Read(nonceBytes); err != nil {
		return fmt.Errorf("failed to generate nonce: %w", err)
	}
	nonce := base64.RawURLEncoding.EncodeToString(nonceBytes)

	state, err := a.states.generate(nonce)
	if err != nil {
		return fmt.Errorf("failed to generate state: %w", err)
	}

	authURL := a.getOAuth2Config().AuthCodeURL(state, oidc.Nonce(nonce))

	slog.Debug("Initiating OIDC login", "redirect_url", authURL)
	http.Redirect(w, r, authURL, http.StatusFound)
	return nil
}

// HandleCallback processes the OAuth2 callback and completes authentication.
func (a *OIDCAuthenticator) HandleCallback(ctx context.Context, code, state string) (*core.AuthResult, error) {
	// Validate state token to prevent CSRF
	nonce, ok := a.states.validate(state)
	if !ok {
		return nil, ErrInvalidState
	}

	if code == "" {
		return nil, ErrMissingCode
	}

	oauth2Token, err := a.getOAuth2Config().Exchange(ctx, code)
	if err != nil {
		slog.Error("Failed to exchange authorization code", "error", err)
		return nil, fmt.Errorf("%w: %w", ErrTokenExchange, err)
	}

	rawIDToken, ok := oauth2Token.Extra("id_token").(string)
	if !ok {
		return nil, ErrNoIDToken
	}

	idToken, err := a.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		slog.Error("Failed to verify ID token", "error", err)
		return nil, fmt.Errorf("%w: %w", ErrTokenVerification, err)
	}

	if idToken.Nonce != nonce {
		return nil, ErrInvalidNonce
	}

	var claims struct {
		Email             string `json:"email"`
		EmailVerified     bool   `json:"email_verified"`
		Name              string `json:"name"`
		PreferredUsername string `json:"preferred_username"`
	}
	if err := idToken.Claims(&claims); err != nil {
		return nil, fmt.Errorf("failed to parse claims: %w", err)
	}

	if !claims.EmailVerified {
		return nil, ErrEmailNotVerified
	}

	email := claims.Email
	if email == "" {
		// Fallback to preferred_username if email is not provided
		email = claims.PreferredUsername
	}
	if email == "" {
		return nil, ErrEmailClaimMissing
	}

	slog.Info("OIDC authentication successful", "email", email, "email_verified", claims.EmailVerified)

	// Check if user exists
	if user := a.core.GetUser(email); user != nil {
		return &core.AuthResult{User: user, Email: email}, nil
	}

	// Auto-create user
	roles := a.core.RolesForNewUser()

	return &core.AuthResult{AutoCreate: true, Email: email, Roles: roles}, nil
}

// GetAuthCodeURL returns the OAuth2 authorization URL for manual redirect handling.
func (a *OIDCAuthenticator) GetAuthCodeURL(state, nonce string) string {
	return a.getOAuth2Config().AuthCodeURL(state, oidc.Nonce(nonce))
}
