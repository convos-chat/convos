package handler

import (
	"log/slog"
	"net/http"

	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
)

// OIDCLoginHandler initiates the OIDC login flow.
func (h *Handler) OIDCLoginHandler(w http.ResponseWriter, r *http.Request) {
	// Check if authenticator is OIDC
	oidcAuth, ok := h.Authenticator.(*auth.OIDCAuthenticator)
	if !ok {
		slog.Error("OIDC login attempted but OIDC authenticator not configured")
		http.Error(w, "OIDC authentication not configured", http.StatusBadRequest)
		return
	}

	if err := oidcAuth.InitiateLogin(w, r); err != nil {
		slog.Error("Failed to initiate OIDC login", "error", err)
		http.Error(w, "Failed to initiate OIDC login", http.StatusInternalServerError)
		return
	}
}

// OIDCCallbackHandler handles the OAuth2 callback from the OIDC provider.
func (h *Handler) OIDCCallbackHandler(w http.ResponseWriter, r *http.Request) {
	// Check if authenticator is OIDC
	oidcAuth, ok := h.Authenticator.(*auth.OIDCAuthenticator)
	if !ok {
		slog.Error("OIDC callback received but OIDC authenticator not configured")
		http.Error(w, "OIDC authentication not configured", http.StatusBadRequest)
		return
	}

	// Extract code and state from query parameters
	code := r.URL.Query().Get("code")
	state := r.URL.Query().Get("state")

	if code == "" {
		// Check for error from provider
		if errMsg := r.URL.Query().Get("error"); errMsg != "" {
			errDesc := r.URL.Query().Get("error_description")
			slog.Warn("OIDC provider returned error", "error", errMsg, "description", errDesc)
			http.Error(w, "Authentication failed: "+errDesc, http.StatusBadRequest)
			return
		}
		http.Error(w, "Missing authorization code", http.StatusBadRequest)
		return
	}

	// Handle callback and get auth result
	result, err := oidcAuth.HandleCallback(r.Context(), code, state)
	if err != nil {
		slog.Error("OIDC callback failed", "error", err)
		http.Error(w, "Authentication failed: "+err.Error(), http.StatusUnauthorized)
		return
	}

	// Get the authenticated user or create a new one
	var user *core.User
	if result.AutoCreate {
		// Auto-create user with OIDC authentication
		user, err = h.createAutoRegisteredUser(result.Email, "", result.Roles)
		if err != nil {
			slog.Error("Failed to auto-register OIDC user", "email", result.Email, "error", err)
			http.Error(w, "Failed to create user account", http.StatusInternalServerError)
			return
		}
		slog.Info("Auto-registered new user via OIDC", "email", result.Email)
	} else {
		user = result.User
		if user == nil {
			http.Error(w, "User not found", http.StatusInternalServerError)
			return
		}
	}

	// Create session
	session, err := h.Store.Get(r, "convos")
	if err != nil {
		slog.Warn("Failed to get session", "error", err)
	}
	session.Values["email"] = user.Email()
	if err = session.Save(r, w); err != nil {
		slog.Error("Failed to save session", "error", err)
		http.Error(w, "Failed to save session", http.StatusInternalServerError)
		return
	}

	// Redirect to chat page
	target := h.makeAbsoluteURL("chat")
	http.Redirect(w, r, target, http.StatusFound)
}
