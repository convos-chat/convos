package core

import (
	"errors"
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
