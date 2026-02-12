package handler

import (
	"context"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
)

// ListConnections implements api.StrictServerInterface.
func (h *Handler) ListConnections(ctx context.Context, request api.ListConnectionsRequestObject) (api.ListConnectionsResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	conns := user.Connections()
	res := make([]api.Connection, len(conns))
	for i, c := range conns {
		res[i] = toAPIConnection(c)
	}

	return api.ListConnections200JSONResponse{Connections: &res}, nil
}

// CreateConnection implements api.StrictServerInterface.
func (h *Handler) CreateConnection(ctx context.Context, request api.CreateConnectionRequestObject) (api.CreateConnectionResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	if request.Body.Url == "" {
		return api.CreateConnectiondefaultJSONResponse{
			StatusCode: http.StatusBadRequest,
			Body:       ErrResponse("URL is required"),
		}, nil
	}

	conn := irc.NewConnection(request.Body.Url, user)
	user.AddConnection(conn)
	if err := h.Core.Backend().SaveConnection(conn); err != nil {
		return nil, err
	}

	// Auto-create conversation from conversation_id param or URL path
	channelName := channelFromURL(request.Body.Url)
	if request.Body.ConversationId != nil && *request.Body.ConversationId != "" {
		channelName = *request.Body.ConversationId
	}
	if channelName != "" {
		conv := core.NewConversation(channelName, conn)
		conn.AddConversation(conv)
		if err := h.Core.Backend().SaveConnection(conn); err != nil {
			slog.Error("Failed to save connection with new conversation", "error", err)
			return nil, err
		}
	}

	// Auto-create connection profile
	h.ensureConnectionProfile(request.Body.Url, false)

	// Auto-connect if wanted state is connected
	if conn.WantedState() == core.StateConnected {
		go func() {
			if err := conn.Connect(); err != nil {
				slog.Error("Failed to auto-connect new connection", "error", err)
			}
		}()
	}

	return api.CreateConnection200JSONResponse(toAPIConnection(conn)), nil
}

// RemoveConnection implements api.StrictServerInterface.
func (h *Handler) RemoveConnection(ctx context.Context, request api.RemoveConnectionRequestObject) (api.RemoveConnectionResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	if err := user.RemoveConnection(request.ConnectionId); err != nil {
		return api.RemoveConnectiondefaultJSONResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       ErrResponse(err.Error()),
		}, nil
	}

	return api.RemoveConnection200JSONResponse{Message: ptr("Connection removed")}, nil
}

// UpdateConnection implements api.StrictServerInterface.
func (h *Handler) UpdateConnection(ctx context.Context, request api.UpdateConnectionRequestObject) (api.UpdateConnectionResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	conn := user.GetConnection(request.ConnectionId)
	if conn == nil {
		return api.UpdateConnectiondefaultJSONResponse{
			StatusCode: http.StatusNotFound,
			Body:       ErrResponse("Connection not found"),
		}, nil
	}

	b := request.Body
	if b.Url != nil && *b.Url != "" {
		newURL, err := url.Parse(*b.Url)
		if err != nil {
			slog.Error("Invalid URL provided for connection update", "error", err)
			return nil, err
		}
		// Ensure password is kept if unchanged
		if newURL.User == nil {
			if existing := conn.URL(); existing != nil {
				newURL.User = existing.User
			}
		}
		conn.SetURL(newURL)
	}
	if b.OnConnectCommands != nil {
		conn.SetOnConnectCommands(*b.OnConnectCommands)
	}
	if b.WantedState != nil {
		newState := core.ConnectionState(*b.WantedState)
		conn.SetWantedState(newState)
		switch newState {
		case core.StateConnected:
			go func() {
				if err := conn.Connect(); err != nil {
					slog.Error("Failed to connect connection", "error", err)
				}
			}()
		case core.StateDisconnected:
			go func() {
				if err := conn.Disconnect(); err != nil {
					slog.Error("Failed to disconnect connection", "error", err)
				}
			}()
		}
	}

	if err := h.Core.Backend().SaveConnection(conn); err != nil {
		return nil, err
	}

	return api.UpdateConnection200JSONResponse(toAPIConnection(conn)), nil
}

// channelFromURL extracts a channel name from a URL path.
// e.g., "irc://irc.libera.chat/%23convos" → "#convos"
func channelFromURL(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	p := strings.TrimPrefix(u.Path, "/")
	if p == "" {
		return ""
	}
	// URL-decode (e.g., %23 → #)
	decoded, err := url.PathUnescape(p)
	if err != nil {
		return p
	}
	return decoded
}

// ensureConnectionProfile creates a connection profile if one doesn't exist for the given URL.
func (h *Handler) ensureConnectionProfile(rawURL string, isDefault bool) {
	id := profileID(rawURL)

	profiles, err := h.Core.Backend().LoadConnectionProfiles()
	if err != nil {
		slog.Error("Failed to load connection profiles", "error", err)
		return
	}
	for _, p := range profiles {
		if p.ID == id {
			return
		}
	}

	profile := core.ConnectionProfileData{
		ID:                 id,
		URL:                rawURL,
		IsDefault:          isDefault,
		SkipQueue:          !isDefault,
		MaxBulkMessageSize: 3,
		MaxMessageLength:   512,
		ServiceAccounts:    []string{"chanserv", "nickserv"},
	}
	if err = h.Core.Backend().SaveConnectionProfile(profile); err != nil {
		slog.Error("Failed to save connection profile", "error", err)
	}
}
