// Package handler provides HTTP handlers for the Convos API. It includes utilities for managing user sessions, constructing absolute URLs, and handling errors in a consistent manner across the API endpoints. The Handler struct serves as a central point for accessing core application logic, embedding services, and session management.
package handler

import (
	"context"
	"crypto/hmac"
	"crypto/sha1" //nolint:gosec // HMAC-SHA1 required for Perl compatibility
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/convos-chat/convos/pkg/bot"
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

type Handler struct {
	Core          *core.Core
	Authenticator core.Authenticator
	EmbedClient   *embed.Client
	I18n          *i18n.Catalog
	Store         sessions.Store
	WebhookNets   []*net.IPNet
	Bot           *bot.Manager
	MaxUploadSize int64
	InviteExpiry  time.Duration
}

func NewHandler(c *core.Core, authenticator core.Authenticator, store sessions.Store, webhookNets []*net.IPNet) *Handler {
	return &Handler{
		Core:          c,
		Authenticator: authenticator,
		EmbedClient:   embed.NewClient(),
		Store:         store,
		WebhookNets:   webhookNets,
		Bot:           bot.NewManager(c),
	}
}

func (h *Handler) getRequest(ctx context.Context) (*http.Request, error) {
	r, ok := ctx.Value(core.CtxKeyRequest).(*http.Request)
	if !ok {
		return nil, ErrRequestNotFound
	}
	return r, nil
}

func (h *Handler) getResponseWriter(ctx context.Context) (http.ResponseWriter, error) {
	w, ok := ctx.Value(core.CtxKeyResponseWriter).(http.ResponseWriter)
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
	user, _ := ctx.Value(core.CtxKeyUser).(*core.User)
	return user
}

func (h *Handler) requireUser(ctx context.Context) (*core.User, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	return user, nil
}

func (h *Handler) requireAdmin(ctx context.Context) error {
	user, err := h.requireUser(ctx)
	if err != nil {
		return err
	}
	if !user.HasRole("admin") {
		return ErrForbidden
	}
	return nil
}

func (h *Handler) saveUserSession(r *http.Request, w http.ResponseWriter, user *core.User) error {
	session, err := h.Store.Get(r, "convos")
	if err != nil {
		slog.Warn("Failed to get session", "err", err)
	}
	session.Values["email"] = user.Email()
	return session.Save(r, w)
}

func (h *Handler) GetUserFromSession(r *http.Request) *core.User {
	session, _ := h.Store.Get(r, "convos")
	email, ok := session.Values["email"].(string)
	if !ok || email == "" {
		return nil
	}

	return h.Core.GetUser(email)
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

