package test

import (
	"fmt"
	"regexp"
	"sync"
	"time"

	"github.com/convos-chat/convos/pkg/core"
)

// MemoryBackend is an in-memory implementation of Backend for testing.
type MemoryBackend struct {
	mu          sync.RWMutex
	users       map[string]core.UserData
	connections map[string][]core.ConnectionData
	messages    map[string][]core.Message
	settings    core.SettingsData
	profiles    map[string]core.ConnectionProfileData
	files       map[string]map[string]core.FileData
	fileContent map[string][]byte
}

// NewTestCore creates a new Core instance backed by an in-memory backend for testing.
func NewTestCore() *core.Core {
	return core.New(core.WithBackend(NewMemoryBackend()))
}

// NewMemoryBackend creates a new in-memory backend.
func NewMemoryBackend() *MemoryBackend {
	return &MemoryBackend{
		users:       make(map[string]core.UserData),
		connections: make(map[string][]core.ConnectionData),
		messages:    make(map[string][]core.Message),
		profiles:    make(map[string]core.ConnectionProfileData),
		files:       make(map[string]map[string]core.FileData),
		fileContent: make(map[string][]byte),
	}
}

// LoadUsers returns all stored users.
func (b *MemoryBackend) LoadUsers() ([]core.UserData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	users := make([]core.UserData, 0, len(b.users))
	for _, u := range b.users {
		users = append(users, u)
	}
	return users, nil
}

// SaveUser stores a user.
func (b *MemoryBackend) SaveUser(user *core.User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.users[user.ID()] = user.ToData(true)
	return nil
}

// DeleteUser removes a user.
func (b *MemoryBackend) DeleteUser(user *core.User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	delete(b.users, user.ID())
	delete(b.connections, user.ID())
	return nil
}

// LoadConnections returns connections for a user.
func (b *MemoryBackend) LoadConnections(user *core.User) ([]core.ConnectionData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	return b.connections[user.ID()], nil
}

// SaveConnection stores a connection.
func (b *MemoryBackend) SaveConnection(conn core.Connection) error {
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
func (b *MemoryBackend) DeleteConnection(conn core.Connection) error {
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
func (b *MemoryBackend) LoadMessages(conv *core.Conversation, query core.MessageQuery) (core.MessageResult, error) {
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

	return core.MessageResult{
		End:      start == 0,
		Messages: msgs[start:],
	}, nil
}

// SaveMessage stores a message.
func (b *MemoryBackend) SaveMessage(conv *core.Conversation, msg core.Message) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	key := conv.Connection().ID() + "/" + conv.ID()
	b.messages[key] = append(b.messages[key], msg)
	return nil
}

// DeleteMessages removes all messages for a conversation.
func (b *MemoryBackend) DeleteMessages(conv *core.Conversation) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	key := conv.Connection().ID() + "/" + conv.ID()
	delete(b.messages, key)
	return nil
}

// SearchMessages searches for messages matching the query.
func (b *MemoryBackend) SearchMessages(user *core.User, query core.MessageQuery) (core.MessageResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	var messages []core.Message
	re, err := regexp.Compile("(?i)" + query.Match)
	if err != nil {
		return core.MessageResult{}, err
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

	return core.MessageResult{
		End:      start == 0,
		Messages: messages[start:],
	}, nil
}

// LoadNotifications returns notifications for a user.
func (b *MemoryBackend) LoadNotifications(user *core.User, query core.MessageQuery) (core.NotificationResult, error) {
	return core.NotificationResult{End: true, Notifications: []core.Notification{}}, nil
}

// SaveNotification stores a notification.
func (b *MemoryBackend) SaveNotification(user *core.User, msg core.Notification) error {
	return nil
}

// LoadSettings returns stored settings.
func (b *MemoryBackend) LoadSettings() (core.SettingsData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.settings, nil
}

// SaveSettings stores settings.
func (b *MemoryBackend) SaveSettings(data core.SettingsData) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.settings = data
	return nil
}

// LoadConnectionProfiles returns all stored connection profiles.
func (b *MemoryBackend) LoadConnectionProfiles() ([]core.ConnectionProfileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	profiles := make([]core.ConnectionProfileData, 0, len(b.profiles))
	for _, p := range b.profiles {
		profiles = append(profiles, p)
	}
	return profiles, nil
}

// SaveConnectionProfile stores a connection profile.
func (b *MemoryBackend) SaveConnectionProfile(profile core.ConnectionProfileData) error {
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
func (b *MemoryBackend) LoadFiles(user *core.User) ([]core.FileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	userFiles := b.files[user.ID()]
	res := make([]core.FileData, 0, len(userFiles))
	for _, f := range userFiles {
		res = append(res, f)
	}
	return res, nil
}

// SaveFile stores a file.
func (b *MemoryBackend) SaveFile(user *core.User, name string, content []byte) (core.FileData, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.files[user.ID()] == nil {
		b.files[user.ID()] = make(map[string]core.FileData)
	}

	id := fmt.Sprintf("%d", time.Now().UnixNano())
	f := core.FileData{
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
func (b *MemoryBackend) DeleteFile(user *core.User, id string) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	if userFiles := b.files[user.ID()]; userFiles != nil {
		delete(userFiles, id)
	}
	delete(b.fileContent, user.ID()+"/"+id)
	return nil
}

// GetFile returns file content and name.
func (b *MemoryBackend) GetFile(user *core.User, id string) ([]byte, string, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	f, ok := b.files[user.ID()][id]
	if !ok {
		return nil, "", core.ErrFileNotFound
	}

	content := b.fileContent[user.ID()+"/"+id]
	return content, f.Name, nil
}
