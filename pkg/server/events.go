package server

import (
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/gorilla/websocket"
)

const (
	methodPing = "ping"
	eventSent  = core.EventTypeSent
)

// newUpgrader creates a WebSocket upgrader that validates the Origin header
// matches the request's Host. This prevents cross-site WebSocket hijacking.
func newUpgrader(c *core.Core) websocket.Upgrader {
	return websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			u, err := url.Parse(origin)
			if err != nil {
				return false
			}
			baseURL := c.Settings.BaseURL()
			slog.Debug("Checking WebSocket origin", "origin", u.Host, "host", baseURL.Host)
			return u.Host == baseURL.Host
		},
	}
}

// wsMessage represents an incoming WebSocket message from the client.
type wsMessage struct {
	Method         string         `json:"method"`
	ID             any            `json:"id,omitempty"`
	Object         string         `json:"object,omitempty"`
	ConnectionID   string         `json:"connection_id,omitempty"`
	ConversationID string         `json:"conversation_id,omitempty"`
	Message        string         `json:"message,omitempty"`
	Params         map[string]any `json:"params,omitempty"`
}

// wsResponse is the base for all outgoing WebSocket responses.
type wsResponse struct {
	Event core.EventType `json:"event"`
	ID    any            `json:"id,omitempty"`
}

// wsPongResponse is the response to a ping message.
type wsPongResponse struct {
	wsResponse
	TS float64 `json:"ts"`
}

// wsLoadResponse is the response to a load message.
type wsLoadResponse struct {
	wsResponse
	User api.User `json:"user"`
}

// wsSentResponse is the response to a send message.
type wsSentResponse struct {
	wsResponse
	ConnectionID   string `json:"connection_id,omitempty"`
	ConversationID string `json:"conversation_id,omitempty"`
	Message        string `json:"message,omitempty"`
	TS             string `json:"ts,omitempty"`
}

// wsErrorResponse represents an error sent over WebSocket.
type wsErrorResponse struct {
	wsResponse
	Errors         []map[string]string `json:"errors"`
	ConnectionID   string              `json:"connection_id,omitempty"`
	ConversationID string              `json:"conversation_id,omitempty"`
	Message        string              `json:"message,omitempty"`
}

func (s *Server) eventsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("Failed to upgrade websocket", "error", err)
		return
	}
	defer conn.Close()

	// Authenticate after upgrade
	// If unauthenticated, send an error event and close with 1008 (Policy Violation)
	// so the client knows not to reconnect.
	user := s.Handler.GetUserFromSession(r)
	if user == nil {
		_ = conn.WriteJSON(map[string]any{
			"errors": []map[string]string{{"message": "Need to log in first."}},
			"event":  "handshake",
		})
		_ = conn.WriteMessage(websocket.CloseMessage,
			websocket.FormatCloseMessage(1008, "Need to log in first."))
		return
	}

	sub := s.Core.EventEmitter.SubscribeUser(user.ID())
	defer sub.Close()

	// Channel for incoming messages from the reader goroutine
	incoming := make(chan wsMessage, 16)
	done := make(chan struct{})

	go func() {
		defer close(done)
		for {
			var msg wsMessage
			if err := conn.ReadJSON(&msg); err != nil {
				return
			}
			incoming <- msg
		}
	}()

	ticker := time.NewTicker(20 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case msg := <-incoming:
			resp := s.handleWSMessage(msg, user)
			if resp != nil {
				if err := conn.WriteJSON(resp); err != nil {
					return
				}
			}
		case event, ok := <-sub.Events:
			if !ok {
				slog.Debug("Event channel closed, ending WS handler")
				return
			}
			if err := conn.WriteJSON(event); err != nil {
				slog.Debug("Failed to write event to WebSocket, closing connection", "error", err)
				return
			}
		case <-ticker.C:
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				slog.Debug("Failed to send ping, closing WebSocket connection", "error", err)
				return
			}
		case <-done:
			return
		}
	}
}

// handleWSMessage dispatches an incoming WebSocket message to the appropriate handler.
func (s *Server) handleWSMessage(msg wsMessage, user *core.User) any {
	if msg.Method == "" {
		msg.Method = methodPing
	}
	slog.Debug("Received WS message", "method", msg.Method, "id", msg.ID, "message", msg.Message)

	switch msg.Method {
	case methodPing:
		return s.handleWSPing(msg)
	case "load":
		return s.handleWSLoad(msg, user)
	case "send":
		return s.handleWSSend(msg, user)
	default:
		slog.Debug("Unknown WS method", "method", msg.Method)
		return wsError("Invalid method.", msg)
	}
}

// handleWSPing responds to a ping with a pong.
func (s *Server) handleWSPing(msg wsMessage) any {
	ts := float64(time.Now().UnixMicro()) / 1e6
	return wsPongResponse{
		wsResponse: wsResponse{
			Event: core.EventTypePong,
			ID:    msg.ID,
		},
		TS: ts,
	}
}

// handleWSLoad returns user data with connections, conversations, and settings.
func (s *Server) handleWSLoad(msg wsMessage, user *core.User) any {
	return wsLoadResponse{
		wsResponse: wsResponse{
			Event: core.EventTypeLoad,
			ID:    msg.ID,
		},
		User: api.ToUser(user, true, true),
	}
}

// handleWSSend forwards a message to an connection.
func (s *Server) handleWSSend(msg wsMessage, user *core.User) any {
	if msg.ConnectionID == "" || msg.Message == "" {
		return wsError("Invalid input.", msg)
	}

	conn := user.GetConnection(msg.ConnectionID)
	if conn == nil {
		return wsError("Connection not found.", msg)
	}

	if err := conn.Send(msg.ConversationID, msg.Message, msg.ID); err != nil {
		return wsError(err.Error(), msg)
	}

	// Commands starting with / produce async responses via the EventEmitter.
	// Don't send an immediate "sent" response for those.
	if strings.HasPrefix(msg.Message, "/") {
		return nil
	}

	return wsSentResponse{
		wsResponse: wsResponse{
			Event: eventSent,
			ID:    msg.ID,
		},
		ConnectionID:   msg.ConnectionID,
		ConversationID: msg.ConversationID,
		Message:        msg.Message,
	}
}

// wsError builds an error response for a WebSocket message.
func wsError(message string, msg wsMessage) any {
	eventName := "unknown"
	switch msg.Method {
	case methodPing:
		eventName = "pong"
	case "send":
		eventName = "sent"
	default:
		if msg.Method != "" {
			eventName = msg.Method
		}
	}

	return wsErrorResponse{
		wsResponse: wsResponse{
			Event: core.EventType(eventName),
			ID:    msg.ID,
		},
		Errors:         []map[string]string{{"message": message}},
		ConnectionID:   msg.ConnectionID,
		ConversationID: msg.ConversationID,
		Message:        msg.Message,
	}
}
