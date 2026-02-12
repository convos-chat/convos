// Package handler provides HTTP handlers for the Convos API. It includes utilities for managing user sessions, constructing absolute URLs, and handling errors in a consistent manner across the API endpoints. The Handler struct serves as a central point for accessing core application logic, embedding services, and session management.
package handler

import (
	"context"
	"crypto/hmac"
	"crypto/sha1" //nolint:gosec // HMAC-SHA1 required for Perl compatibility
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/embed"
	"github.com/convos-chat/convos/pkg/i18n"
	"github.com/gorilla/sessions"
)

var (
	ErrRequestNotFound        = errors.New("internal error: request not found in context")
	ErrResponseWriterNotFound = errors.New("internal error: response writer not found in context")
	ErrUnauthorized           = errors.New("unauthorized")
	ErrForbidden              = errors.New("forbidden")
	ErrInvalidInviteToken     = errors.New("invalid token. You have to ask your Convos admin for a new link")
)

type ctxKey string

const (
	CtxKeyRequest        ctxKey = "http.Request"
	CtxKeyResponseWriter ctxKey = "http.ResponseWriter"
	CtxKeyUser           ctxKey = "core.User"
)

type Handler struct {
	Core        *core.Core
	EmbedClient *embed.Client
	I18n        *i18n.Catalog
	Store       sessions.Store
	WebhookNets []*net.IPNet
}

func NewHandler(c *core.Core, store sessions.Store, webhookNets []*net.IPNet) *Handler {
	return &Handler{Core: c, EmbedClient: embed.NewClient(), Store: store, WebhookNets: webhookNets}
}

func (h *Handler) getRequest(ctx context.Context) (*http.Request, error) {
	r, ok := ctx.Value(CtxKeyRequest).(*http.Request)
	if !ok {
		return nil, ErrRequestNotFound
	}
	return r, nil
}

func (h *Handler) getResponseWriter(ctx context.Context) (http.ResponseWriter, error) {
	w, ok := ctx.Value(CtxKeyResponseWriter).(http.ResponseWriter)
	if !ok {
		return nil, ErrResponseWriterNotFound
	}
	return w, nil
}

func (h *Handler) makeAbsoluteURL(path string) string {
	baseURL := h.Core.Settings().BaseURL()
	rel, _ := url.Parse(path)
	return baseURL.ResolveReference(rel).String()
}

func (h *Handler) GetUserFromCtx(ctx context.Context) *core.User {
	user, _ := ctx.Value(CtxKeyUser).(*core.User)
	return user
}

func (h *Handler) GetUserFromSession(r *http.Request) *core.User {
	session, _ := h.Store.Get(r, "convos")
	email, ok := session.Values["email"].(string)
	if !ok || email == "" {
		return nil
	}

	return h.Core.GetUser(email)
}

func ptr[T any](v T) *T {
	return &v
}

// inviteToken computes HMAC-SHA1 of "email:{email}:exp:{exp}:password:{password}"
// keyed with the given secret. Matches Perl's _add_invite_token_to_params.
func inviteToken(email string, exp int64, password, secret string) string {
	data := fmt.Sprintf("email:%s:exp:%d:password:%s", email, exp, password)
	mac := hmac.New(sha1.New, []byte(secret))
	mac.Write([]byte(data))
	return hex.EncodeToString(mac.Sum(nil))
}

// generateInviteToken creates a token using the primary session secret.
func (h *Handler) generateInviteToken(email string, exp int64, password string) string {
	secrets := h.Core.Settings().SessionSecrets()
	if len(secrets) == 0 {
		return ""
	}
	return inviteToken(email, exp, password, secrets[0])
}

// validateInviteToken checks a token against all session secrets (supports key rotation).
func (h *Handler) validateInviteToken(email, token string, exp int64, password string) bool {
	for _, secret := range h.Core.Settings().SessionSecrets() {
		if inviteToken(email, exp, password, secret) == token {
			return true
		}
	}
	return false
}

func ErrResponse(message string) api.Error {
	return api.Error{
		Errors: &[]struct {
			Message string  `json:"message"`
			Path    *string `json:"path,omitempty"`
		}{
			{Message: message, Path: ptr("/")},
		},
	}
}
