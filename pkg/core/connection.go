package core

import (
	"errors"
	"maps"
	"net"
	"net/url"
	"strings"
	"sync"
)

// ConnectionState represents the state of a connection.
type ConnectionState string

var ErrNoReplyExpected = errors.New("no reply expected for this command")

const (
	StateDisconnected  ConnectionState = "disconnected"
	StateConnecting    ConnectionState = "connecting"
	StateConnected     ConnectionState = "connected"
	StateDisconnecting ConnectionState = "disconnecting"
	StateQueued        ConnectionState = "queued"
)

// Connection represents a connection to a chat server.
type Connection interface {
	// ID returns the unique identifier for this connection.
	ID() string

	// Name returns the display name for this connection.
	Name() string

	// SetName sets the display name.
	SetName(name string)

	// URL returns the connection URL.
	URL() *url.URL

	// SetURL sets the connection URL.
	SetURL(u *url.URL)

	// User returns the owning user.
	User() *User

	// State returns the current connection state.
	State() ConnectionState

	// WantedState returns the desired connection state.
	WantedState() ConnectionState

	// SetWantedState sets the desired connection state.
	SetWantedState(state ConnectionState)

	// Connect initiates a connection.
	Connect() error

	// Disconnect closes the connection.
	Disconnect() error

	// Send sends a message to a target.
	Send(target, message string) error

	// List returns the current channel list cache state immediately, triggering
	// a fresh IRC LIST fetch if the cache is empty or refresh is requested.
	List(args string) (map[string]any, error)

	// Mode registers a pending mode query and sends MODE to IRC. The response
	// arrives asynchronously as a SentEvent carrying requestID.
	Mode(channel string, requestID any) error

	// Names registers a pending names query and sends NAMES to IRC. The response
	// arrives asynchronously as a SentEvent carrying requestID.
	Names(channel string, requestID any) error

	// Nick returns the current nickname.
	Nick() string

	// Info returns connection info.
	Info() map[string]any

	// SetInfo sets a connection info key.
	SetInfo(key string, value any)

	// Conversations returns all conversations.
	Conversations() []*Conversation

	// GetConversation returns a conversation by ID.
	GetConversation(id string) *Conversation

	// AddConversation adds a conversation.
	AddConversation(conv *Conversation)

	// RemoveConversation removes a conversation.
	RemoveConversation(id string)

	// OnConnectCommands returns commands to run on connect.
	OnConnectCommands() []string

	// SetOnConnectCommands sets commands to run on connect.
	SetOnConnectCommands(cmds []string)

	// Profile returns the connection profile.
	Profile() *ConnectionProfile

	// ToData converts to serializable format.
	ToData(persist bool) ConnectionData

	LogServerError(message string)
}

// ConnectionData represents serialized connection data.
type ConnectionData struct {
	ID                string             `json:"connection_id"`
	Info              map[string]any     `json:"info,omitempty"`
	Name              string             `json:"name"`
	URL               string             `json:"url"`
	WantedState       ConnectionState    `json:"wanted_state"`
	State             ConnectionState    `json:"state,omitempty"`
	OnConnectCommands []string           `json:"on_connect_commands"`
	Conversations     []ConversationData `json:"conversations,omitempty"`
}

// BaseConnection provides common functionality for connections.
type BaseConnection struct {
	mu                sync.RWMutex
	id                string
	name              string
	url               *url.URL
	user              *User
	state             ConnectionState
	wantedState       ConnectionState
	onConnectCommands []string
	conversations     map[string]*Conversation
	info              map[string]any
	profile           *ConnectionProfile
}

// NewBaseConnection creates a new base connection.
func NewBaseConnection(rawURL string, user *User) *BaseConnection {
	u, _ := url.Parse(rawURL)

	// Ensure the URL always has a nick parameter so the frontend can identify
	// the user's own messages. Derive from email if not explicitly set.
	if u != nil && u.Query().Get("nick") == "" && user != nil {
		nick := defaultNickFromEmail(user.Email())
		q := u.Query()
		q.Set("nick", nick)
		u.RawQuery = q.Encode()
	}

	var profile *ConnectionProfile
	if user != nil && user.Core() != nil && u != nil {
		profile = user.Core().ConnectionProfile(u)
	}

	return &BaseConnection{
		url:               u,
		user:              user,
		state:             StateDisconnected,
		wantedState:       StateConnected,
		onConnectCommands: []string{},
		conversations:     make(map[string]*Conversation),
		info:              make(map[string]any),
		profile:           profile,
	}
}

// ID returns the connection identifier.
func (c *BaseConnection) ID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.id != "" {
		return c.id
	}

	// Generate ID from URL: scheme-hostname
	if c.url != nil {
		c.id = strings.ToLower(c.url.Scheme + "-" + PrettyConnectionName(c.url.Host))
	}
	return c.id
}

// Name returns the connection name.
func (c *BaseConnection) Name() string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.name != "" {
		return c.name
	}
	if c.url != nil {
		return PrettyConnectionName(c.url.Host)
	}
	return ""
}

// SetName sets the connection name.
func (c *BaseConnection) SetName(name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.name = name
}

// URL returns the connection URL.
func (c *BaseConnection) URL() *url.URL {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.url
}

// SetURL sets the connection URL.
func (c *BaseConnection) SetURL(u *url.URL) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.url = u
}

// User returns the owning user.
func (c *BaseConnection) User() *User {
	return c.user
}

// State returns the current connection state.
func (c *BaseConnection) State() ConnectionState {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.state
}

// SetState sets the connection state.
func (c *BaseConnection) SetState(state ConnectionState) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.state = state
}

// WantedState returns the desired connection state.
func (c *BaseConnection) WantedState() ConnectionState {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.wantedState
}

// SetWantedState sets the desired connection state.
func (c *BaseConnection) SetWantedState(state ConnectionState) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.wantedState = state
}

// OnConnectCommands returns commands to run on connect.
func (c *BaseConnection) OnConnectCommands() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.onConnectCommands
}

// SetOnConnectCommands sets commands to run on connect.
func (c *BaseConnection) SetOnConnectCommands(cmds []string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.onConnectCommands = cmds
}

// Profile returns the connection profile.
func (c *BaseConnection) Profile() *ConnectionProfile {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.profile
}

// Conversations returns all conversations.
func (c *BaseConnection) Conversations() []*Conversation {
	c.mu.RLock()
	defer c.mu.RUnlock()

	convs := make([]*Conversation, 0, len(c.conversations))
	for _, conv := range c.conversations {
		convs = append(convs, conv)
	}
	return convs
}

// GetConversation returns a conversation by ID.
func (c *BaseConnection) GetConversation(id string) *Conversation {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.conversations[strings.ToLower(id)]
}

// AddConversation adds a conversation.
func (c *BaseConnection) AddConversation(conv *Conversation) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.conversations[conv.ID()] = conv
}

// RemoveConversation removes a conversation.
func (c *BaseConnection) RemoveConversation(id string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.conversations, strings.ToLower(id))
}

// Info returns connection info.
func (c *BaseConnection) Info() map[string]any {
	c.mu.RLock()
	defer c.mu.RUnlock()

	info := make(map[string]any)
	maps.Copy(info, c.info)
	return info
}

// SetInfo sets a connection info key.
func (c *BaseConnection) SetInfo(key string, value any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.info[key] = value
}

// Nick returns the current nickname (base implementation).
func (c *BaseConnection) Nick() string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	// Try to get nick from URL query
	if c.url != nil {
		if nick := c.url.Query().Get("nick"); nick != "" {
			return nick
		}
	}

	// Default to part before @ in email
	if c.user != nil {
		return defaultNickFromEmail(c.user.Email())
	}

	return "guest"
}

// defaultNickFromEmail derives a nick from an email address by taking the local
// part and replacing non-word characters with underscores.
func defaultNickFromEmail(email string) string {
	if idx := strings.Index(email, "@"); idx > 0 {
		nick := email[:idx]
		return strings.Map(func(r rune) rune {
			if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' {
				return r
			}
			return '_'
		}, nick)
	}
	return "guest"
}

// ToData converts to serializable format.
func (c *BaseConnection) ToData(persist bool) ConnectionData {
	c.mu.RLock()
	defer c.mu.RUnlock()

	data := ConnectionData{
		ID:                c.ID(),
		Info:              c.Info(),
		Name:              c.Name(),
		WantedState:       c.wantedState,
		OnConnectCommands: c.onConnectCommands,
	}

	if c.url != nil {
		data.URL = c.url.String()
	}

	if persist {
		data.Conversations = make([]ConversationData, 0, len(c.conversations))
		for _, conv := range c.conversations {
			data.Conversations = append(data.Conversations, conv.ToData(persist))
		}
	} else {
		data.State = c.state
	}

	return data
}

// PrettyConnectionName extracts a clean name from a hostname.
func PrettyConnectionName(host string) string {
	// Remove port if present
	if idx := strings.LastIndex(host, ":"); idx > 0 {
		host = host[:idx]
	}

	// Use IP address as is
	if net.ParseIP(host) != nil {
		return host
	}

	// Remove common prefixes like "irc."
	parts := strings.Split(host, ".")
	if len(parts) > 2 {
		// Skip common IRC prefixes
		if parts[0] == "irc" || parts[0] == "chat" {
			parts = parts[1:]
		}
	}

	// Take the main domain part
	if len(parts) >= 2 {
		return parts[len(parts)-2]
	}
	return host
}
