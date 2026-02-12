package core

import (
	"errors"
	"fmt"
	"regexp"
	"sync"
	"time"
)

var ErrFileNotFound = errors.New("file not found")

// Backend defines the storage interface for Convos.
type Backend interface {
	// User operations
	LoadUsers() ([]UserData, error)
	SaveUser(user *User) error
	DeleteUser(user *User) error

	// Connection operations
	LoadConnections(user *User) ([]ConnectionData, error)
	SaveConnection(conn Connection) error
	DeleteConnection(conn Connection) error

	// Message operations
	LoadMessages(conv *Conversation, query MessageQuery) (MessageResult, error)
	SaveMessage(conv *Conversation, msg Message) error
	DeleteMessages(conv *Conversation) error
	SearchMessages(user *User, query MessageQuery) (MessageResult, error)

	// Notification operations
	LoadNotifications(user *User, query MessageQuery) (NotificationResult, error)
	SaveNotification(user *User, msg Notification) error

	// Settings operations
	LoadSettings() (SettingsData, error)
	SaveSettings(data SettingsData) error

	// Profile operations
	LoadConnectionProfiles() ([]ConnectionProfileData, error)
	SaveConnectionProfile(profile ConnectionProfileData) error
	DeleteConnectionProfile(id string) error

	// File operations
	LoadFiles(user *User) ([]FileData, error)
	SaveFile(user *User, name string, content []byte) (FileData, error)
	DeleteFile(user *User, id string) error
	GetFile(user *User, id string) ([]byte, string, error) // returns content and original filename
}

// FileData represents metadata for an uploaded file.
type FileData struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Size int64  `json:"size"`
	TS   int64  `json:"ts"`
}

// ConnectionProfileData represents a connection profile.
type ConnectionProfileData struct {
	ID                 string   `json:"id"`
	IsDefault          bool     `json:"is_default"`
	IsForced           bool     `json:"is_forced"`
	MaxBulkMessageSize int      `json:"max_bulk_message_size"`
	MaxMessageLength   int      `json:"max_message_length"`
	ServiceAccounts    []string `json:"service_accounts"`
	SkipQueue          bool     `json:"skip_queue"`
	URL                string   `json:"url"`
	WebircPassword     string   `json:"webirc_password"`
}

// Notification represents a highlight notification.
type Notification struct {
	ConnectionID   string `json:"connection_id"`
	ConversationID string `json:"conversation_id"`
	From           string `json:"from"`
	Message        string `json:"message"`
	Type           string `json:"type"`
	Timestamp      int64  `json:"ts"`
}

// NotificationResult contains the result of a notification query.
type NotificationResult struct {
	End           bool           `json:"end"`
	Notifications []Notification `json:"notifications"`
}

// SettingsData represents serialized settings.
type SettingsData struct {
	BaseURL           string   `json:"base_url,omitempty"`
	Contact           string   `json:"contact,omitempty"`
	DefaultConnection string   `json:"default_connection,omitempty"`
	ForcedConnection  bool     `json:"forced_connection,omitempty"`
	LocalSecret       string   `json:"local_secret,omitempty"`
	OpenToPublic      bool     `json:"open_to_public,omitempty"`
	OrganizationName  string   `json:"organization_name,omitempty"`
	OrganizationURL   string   `json:"organization_url,omitempty"`
	SessionSecrets    []string `json:"session_secrets,omitempty"`
	VideoService      string   `json:"video_service,omitempty"`
	VAPIDPrivateKey   string   `json:"vapid_private_key,omitempty"`
	VAPIDPublicKey    string   `json:"vapid_public_key,omitempty"`
}

// MessageQuery defines parameters for message searches.
type MessageQuery struct {
	After  string // Find messages after this ISO 8601 timestamp
	Around string // Find messages around this ISO 8601 timestamp
	Before string // Find messages before this ISO 8601 timestamp
	Limit  int    // Max number of messages
	Match  string // Filter by regexp
}

// MessageResult contains the result of a message query.
type MessageResult struct {
	End      bool      `json:"end"`
	Messages []Message `json:"messages"`
}

// Message represents a chat message.
type Message struct {
	From      string `json:"from"`
	Message   string `json:"message"`
	Highlight bool   `json:"highlight"`
	Type      string `json:"type"` // action, error, notice, privmsg
	Timestamp int64  `json:"ts"`
}

// MemoryBackend is an in-memory implementation of Backend for testing.
type MemoryBackend struct {
	mu          sync.RWMutex
	users       map[string]UserData
	connections map[string][]ConnectionData
	messages    map[string][]Message
	settings    SettingsData
	profiles    map[string]ConnectionProfileData
	files       map[string]map[string]FileData
	fileContent map[string][]byte
}

// NewMemoryBackend creates a new in-memory backend.
func NewMemoryBackend() *MemoryBackend {
	return &MemoryBackend{
		users:       make(map[string]UserData),
		connections: make(map[string][]ConnectionData),
		messages:    make(map[string][]Message),
		profiles:    make(map[string]ConnectionProfileData),
		files:       make(map[string]map[string]FileData),
		fileContent: make(map[string][]byte),
	}
}

// LoadUsers returns all stored users.
func (b *MemoryBackend) LoadUsers() ([]UserData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	users := make([]UserData, 0, len(b.users))
	for _, u := range b.users {
		users = append(users, u)
	}
	return users, nil
}

// SaveUser stores a user.
func (b *MemoryBackend) SaveUser(user *User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.users[user.ID()] = user.ToData(true)
	return nil
}

// DeleteUser removes a user.
func (b *MemoryBackend) DeleteUser(user *User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	delete(b.users, user.ID())
	delete(b.connections, user.ID())
	return nil
}

// LoadConnections returns connections for a user.
func (b *MemoryBackend) LoadConnections(user *User) ([]ConnectionData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	return b.connections[user.ID()], nil
}

// SaveConnection stores a connection.
func (b *MemoryBackend) SaveConnection(conn Connection) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	userID := conn.User().ID()
	conns := b.connections[userID]

	// Update or append
	found := false
	for i, c := range conns {
		if c.ID == conn.ID() {
			conns[i] = conn.ToData(true)
			found = true
			break
		}
	}
	if !found {
		conns = append(conns, conn.ToData(true))
	}

	b.connections[userID] = conns
	return nil
}

// DeleteConnection removes a connection.
func (b *MemoryBackend) DeleteConnection(conn Connection) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	userID := conn.User().ID()
	conns := b.connections[userID]

	for i, c := range conns {
		if c.ID == conn.ID() {
			b.connections[userID] = append(conns[:i], conns[i+1:]...)
			break
		}
	}
	return nil
}

// LoadMessages returns messages for a conversation.
func (b *MemoryBackend) LoadMessages(conv *Conversation, query MessageQuery) (MessageResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	key := conv.Connection().ID() + "/" + conv.ID()
	msgs := b.messages[key]

	limit := query.Limit
	if limit <= 0 || limit > 200 {
		limit = 60
	}

	// When around is set, treat it as before if before is not set
	if query.Around != "" && query.Before == "" {
		query.Before = query.Around
	}

	// FIXME: Simple implementation - return last N messages
	start := 0
	if len(msgs) > limit {
		start = len(msgs) - limit
	}

	return MessageResult{
		End:      start == 0,
		Messages: msgs[start:],
	}, nil
}

// SaveMessage stores a message.
func (b *MemoryBackend) SaveMessage(conv *Conversation, msg Message) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	key := conv.Connection().ID() + "/" + conv.ID()
	b.messages[key] = append(b.messages[key], msg)
	return nil
}

// DeleteMessages removes all messages for a conversation.
func (b *MemoryBackend) DeleteMessages(conv *Conversation) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	key := conv.Connection().ID() + "/" + conv.ID()
	delete(b.messages, key)
	return nil
}

// SearchMessages searches for messages matching the query.
func (b *MemoryBackend) SearchMessages(user *User, query MessageQuery) (MessageResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	var messages []Message
	re, err := regexp.Compile("(?i)" + query.Match)
	if err != nil {
		return MessageResult{}, err
	}

	for _, userConns := range b.connections[user.ID()] {
		for _, conv := range userConns.Conversations {
			key := userConns.ID + "/" + conv.ConversationID
			for _, msg := range b.messages[key] {
				if re.MatchString(msg.Message) {
					messages = append(messages, msg)
				}
			}
		}
	}

	// Simple implementation - return last N messages
	limit := query.Limit
	if limit <= 0 || limit > 200 {
		limit = 60
	}

	start := 0
	if len(messages) > limit {
		start = len(messages) - limit
	}

	return MessageResult{
		End:      start == 0,
		Messages: messages[start:],
	}, nil
}

// LoadNotifications returns notifications for a user.
func (b *MemoryBackend) LoadNotifications(user *User, query MessageQuery) (NotificationResult, error) {
	return NotificationResult{End: true, Notifications: []Notification{}}, nil
}

// SaveNotification stores a notification.
func (b *MemoryBackend) SaveNotification(user *User, msg Notification) error {
	return nil
}

// LoadSettings returns stored settings.
func (b *MemoryBackend) LoadSettings() (SettingsData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.settings, nil
}

// SaveSettings stores settings.
func (b *MemoryBackend) SaveSettings(data SettingsData) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.settings = data
	return nil
}

// LoadConnectionProfiles returns all stored connection profiles.
func (b *MemoryBackend) LoadConnectionProfiles() ([]ConnectionProfileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	profiles := make([]ConnectionProfileData, 0, len(b.profiles))
	for _, p := range b.profiles {
		profiles = append(profiles, p)
	}
	return profiles, nil
}

// SaveConnectionProfile stores a connection profile.
func (b *MemoryBackend) SaveConnectionProfile(profile ConnectionProfileData) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.profiles[profile.ID] = profile
	return nil
}

// DeleteConnectionProfile removes a connection profile.
func (b *MemoryBackend) DeleteConnectionProfile(id string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	delete(b.profiles, id)
	return nil
}

// LoadFiles returns all files for a user.
func (b *MemoryBackend) LoadFiles(user *User) ([]FileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	userFiles := b.files[user.ID()]
	res := make([]FileData, 0, len(userFiles))
	for _, f := range userFiles {
		res = append(res, f)
	}
	return res, nil
}

// SaveFile stores a file.
func (b *MemoryBackend) SaveFile(user *User, name string, content []byte) (FileData, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.files[user.ID()] == nil {
		b.files[user.ID()] = make(map[string]FileData)
	}

	id := fmt.Sprintf("%d", time.Now().UnixNano())
	f := FileData{
		ID:   id,
		Name: name,
		Size: int64(len(content)),
		TS:   time.Now().Unix(),
	}

	b.files[user.ID()][id] = f
	b.fileContent[user.ID()+"/"+id] = content
	return f, nil
}

// DeleteFile removes a file.
func (b *MemoryBackend) DeleteFile(user *User, id string) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	if userFiles := b.files[user.ID()]; userFiles != nil {
		delete(userFiles, id)
	}
	delete(b.fileContent, user.ID()+"/"+id)
	return nil
}

// GetFile returns file content and name.
func (b *MemoryBackend) GetFile(user *User, id string) ([]byte, string, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	f, ok := b.files[user.ID()][id]
	if !ok {
		return nil, "", ErrFileNotFound
	}

	content := b.fileContent[user.ID()+"/"+id]
	return content, f.Name, nil
}
