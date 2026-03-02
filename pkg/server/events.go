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
func newUpgrader() websocket.Upgrader {
	return websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			if origin == "" {
				return true // non-browser clients may omit Origin
			}
			u, err := url.Parse(origin)
			if err != nil {
				return false
			}
			return u.Host == r.Host
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

	// Authenticate after upgrade (matching Perl behavior).
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

	sub := s.Core.Events().SubscribeUser(user.ID())
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
		case event, ok := <-sub.Events():
			if !ok {
				return
			}
			if err := conn.WriteJSON(event); err != nil {
				return
			}
		case <-ticker.C:
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
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

// handleWSSend forwards a message to an IRC connection.
func (s *Server) handleWSSend(msg wsMessage, user *core.User) any {
	if msg.ConnectionID == "" || msg.Message == "" {
		return wsError("Invalid input.", msg)
	}

	conn := user.GetConnection(msg.ConnectionID)
	if conn == nil {
		return wsError("Connection not found.", msg)
	}

	// /list is handled synchronously: return the current cache state immediately
	// (triggering a fresh IRC LIST fetch when needed) so the frontend's polling
	// loop fires correctly — matching Perl's _send_list_p behaviour.
	if args, ok := parseListArgs(msg.Message); ok {
		result, err := conn.List(args)
		if err != nil {
			return wsError(err.Error(), msg)
		}

		// Inject common fields into the result map
		result["event"] = eventSent
		result["connection_id"] = msg.ConnectionID
		result["conversation_id"] = msg.ConversationID
		result["message"] = msg.Message
		result["ts"] = time.Now().Format(time.RFC3339)
		if msg.ID != nil {
			result["id"] = msg.ID
		}
		return result
	}

	// /names registers a pending query and sends NAMES to IRC. The response
	// arrives asynchronously as a SentEvent carrying requestID — matching
	// Perl's _send_names_p write-and-wait behaviour.
	if channel, ok := parseNamesArgs(msg.Message); ok {
		if err := conn.Names(channel, msg.ID); err != nil {
			return wsError(err.Error(), msg)
		}
		return nil // response arrives asynchronously via SentEvent
	}

	// /mode (no args) is a channel mode query. Register the request ID so that
	// when RPL_CHANNELMODEIS (324) arrives the handler can emit a SentEvent
	// carrying this ID — matching Perl's _send_mode_p behaviour without blocking.
	if channel, ok := parseModeQueryArgs(msg.Message, msg.ConversationID); ok {
		if err := conn.Mode(channel, msg.ID); err != nil {
			return wsError(err.Error(), msg)
		}
		return nil // response arrives asynchronously via SentEvent
	}

	if err := conn.Send(msg.ConversationID, msg.Message); err != nil {
		return wsError(err.Error(), msg)
	}

	// Commands starting with / produce async responses via the EventEmitter
	// (e.g. /whois, /names). Don't send an immediate "sent" response for those
	// because it would lack the required "command" field and break the frontend.
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

// parseListArgs checks whether message is a /list command (case-insensitive)
// and returns the arguments after "/list". Returns ok=false for anything else.
func parseListArgs(message string) (string, bool) {
	if len(message) < 5 || !strings.EqualFold(message[:5], "/list") {
		return "", false
	}
	rest := message[5:]
	if rest != "" && rest[0] != ' ' {
		return "", false // e.g. /listing — not a /list command
	}
	return strings.TrimSpace(rest), true
}

// parseNamesArgs checks whether message is a /names command (case-insensitive)
// and returns the channel name. Returns ok=false for anything else.
func parseNamesArgs(message string) (string, bool) {
	if len(message) < 6 || !strings.EqualFold(message[:6], "/names") {
		return "", false
	}
	rest := message[6:]
	if rest != "" && rest[0] != ' ' {
		return "", false // e.g. /namespace — not a /names command
	}
	return strings.TrimSpace(rest), true
}

// parseModeQueryArgs checks whether message is a bare "/mode" command with no
// arguments (a channel mode query). Returns the target channel from conversationID
// and ok=true. Mode set commands ("/mode +o nick") or other variants return ok=false.
func parseModeQueryArgs(message string, conversationID string) (string, bool) {
	if !strings.EqualFold(strings.TrimSpace(message), "/mode") {
		return "", false
	}
	if conversationID == "" {
		return "", false
	}
	return conversationID, true
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
