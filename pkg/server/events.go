package server

import (
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/gorilla/websocket"
)

const methodPing = "ping"

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
func (s *Server) handleWSMessage(msg wsMessage, user *core.User) map[string]any {
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
func (s *Server) handleWSPing(msg wsMessage) map[string]any {
	ts := float64(time.Now().UnixMicro()) / 1e6
	resp := map[string]any{
		"event": "pong",
		"ts":    ts,
	}
	if msg.ID != nil {
		resp["id"] = msg.ID
	}
	return resp
}

// handleWSLoad returns user data with connections, conversations, and settings.
func (s *Server) handleWSLoad(msg wsMessage, user *core.User) map[string]any {
	settings := s.Core.Settings()

	// Build user object matching Perl's TO_JSON + get_p
	userData := map[string]any{
		"email":              user.Email(),
		"highlight_keywords": user.HighlightKeywords(),
		"registered":         user.Registered().Format(time.RFC3339),
		"roles":              user.Roles(),
		"uid":                strconv.Itoa(user.UID()),
		"unread":             user.Unread(),
	}

	// Build connections and conversations arrays
	conns := user.Connections()
	connList := make([]map[string]any, 0, len(conns))
	convList := make([]map[string]any, 0, len(conns)*4)

	for _, c := range conns {
		connList = append(connList, wsConnectionData(c))
		for _, conv := range c.Conversations() {
			convList = append(convList, wsConversationData(conv))
		}
	}

	userData["connections"] = connList
	userData["conversations"] = convList

	// Add settings (matching Perl's _event_load)
	userData["default_connection"] = settings.DefaultConnection()
	userData["forced_connection"] = settings.ForcedConnection()
	userData["video_service"] = settings.VideoService()

	resp := map[string]any{
		"event": "load",
		"user":  userData,
	}
	if msg.ID != nil {
		resp["id"] = msg.ID
	}
	return resp
}

// handleWSSend forwards a message to an IRC connection.
func (s *Server) handleWSSend(msg wsMessage, user *core.User) map[string]any {
	if msg.ConnectionID == "" || msg.Message == "" {
		return wsError("Invalid input.", msg)
	}

	conn := user.GetConnection(msg.ConnectionID)
	if conn == nil {
		return wsError("Connection not found.", msg)
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

	resp := map[string]any{
		"event":           "sent",
		"connection_id":   msg.ConnectionID,
		"conversation_id": msg.ConversationID,
		"message":         msg.Message,
	}
	if msg.ID != nil {
		resp["id"] = msg.ID
	}
	return resp
}

// wsError builds an error response for a WebSocket message.
func wsError(message string, msg wsMessage) map[string]any {
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

	resp := map[string]any{
		"event":  eventName,
		"errors": []map[string]string{{"message": message}},
	}
	if msg.ID != nil {
		resp["id"] = msg.ID
	}
	if msg.ConnectionID != "" {
		resp["connection_id"] = msg.ConnectionID
	}
	if msg.Message != "" {
		resp["message"] = msg.Message
	}
	return resp
}

// wsConnectionData builds a connection map for WebSocket responses.
func wsConnectionData(c core.Connection) map[string]any {
	urlStr := ""
	if u := c.URL(); u != nil {
		clean := *u
		clean.User = nil
		urlStr = clean.String()
	}

	return map[string]any{
		"connection_id":       c.ID(),
		"name":                c.Name(),
		"url":                 urlStr,
		"state":               string(c.State()),
		"wanted_state":        string(c.WantedState()),
		"on_connect_commands": c.OnConnectCommands(),
	}
}

// wsConversationData builds a conversation map for WebSocket responses.
func wsConversationData(conv *core.Conversation) map[string]any {
	data := map[string]any{
		"connection_id":   conv.Connection().ID(),
		"conversation_id": conv.ID(),
		"frozen":          conv.Frozen(),
		"name":            conv.Name(),
		"notifications":   conv.Notifications(),
		"topic":           conv.Topic(),
		"unread":          conv.Unread(),
		"participants":    conv.Participants(),
	}
	if modes := conv.Modes(); modes != nil {
		data["modes"] = modes
	}
	return data
}
