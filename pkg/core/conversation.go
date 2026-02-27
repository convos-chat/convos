package core

import (
	"maps"
	"regexp"
	"strings"
	"sync"
)

// ChannelRE matches IRC channel names.
var ChannelRE = regexp.MustCompile(`^[#&!+]`)

// channelModeNames maps IRC mode characters to human-readable names,
// matching the frontend's channelModeCharToModeName in constants.js.
var channelModeNames = map[byte]string{
	'i': "invite_only",
	'm': "moderated",
	'k': "password",
	'n': "prevent_external_send",
	't': "topic_protection",
}

// Conversation represents a chat conversation (channel or private message).
type Conversation struct {
	mu            sync.RWMutex
	connection    Connection
	id            string
	name          string
	topic         string
	password      string
	frozen        string
	notifications int
	unread        int
	modes         map[string]bool
	info          map[string]any
	participants  map[string]Participant
}

// ConversationData represents serialized conversation data.
type ConversationData struct {
	ConnectionID   string                    `json:"connection_id"`
	ConversationID string                    `json:"conversation_id"`
	Name           string                    `json:"name"`
	Topic          string                    `json:"topic"`
	Password       string                    `json:"password,omitempty"`
	Frozen         string                    `json:"frozen"`
	Notifications  int                       `json:"notifications"`
	Unread         int                       `json:"unread"`
	Info           map[string]any            `json:"info"`
	Participants   map[string]Participant    `json:"participants,omitempty"`
}

// NewConversation creates a new conversation.
func NewConversation(name string, conn Connection) *Conversation {
	return NewConversationWithID(strings.ToLower(name), name, conn)
}

// NewConversationWithID creates a new conversation with a specific ID.
func NewConversationWithID(id, name string, conn Connection) *Conversation {
	return &Conversation{
		connection:   conn,
		name:         name,
		id:           id,
		info:         make(map[string]any),
		participants: make(map[string]Participant),
	}
}

// Connection returns the parent connection.
func (c *Conversation) Connection() Connection {
	return c.connection
}

// ID returns the conversation identifier.
func (c *Conversation) ID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.id
}

// Name returns the conversation name.
func (c *Conversation) Name() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.name
}

// Topic returns the conversation topic.
func (c *Conversation) Topic() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.topic
}

// SetTopic sets the conversation topic.
func (c *Conversation) SetTopic(topic string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.topic = topic
}

// Password returns the conversation password.
func (c *Conversation) Password() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.password
}

// SetPassword sets the conversation password.
func (c *Conversation) SetPassword(password string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.password = password
}

// Frozen returns the frozen status message, or empty if not frozen.
func (c *Conversation) Frozen() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.frozen
}

// SetFrozen sets the frozen status.
func (c *Conversation) SetFrozen(msg string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.frozen = msg
}

// IsPrivate returns true if this is a private conversation (not a channel).
func (c *Conversation) IsPrivate() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return !ChannelRE.MatchString(c.name)
}

// Notifications returns the notification count.
func (c *Conversation) Notifications() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.notifications
}

// IncNotifications increments the notification count.
func (c *Conversation) IncNotifications() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.notifications++
}

// SetNotifications sets the notification count.
func (c *Conversation) SetNotifications(n int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.notifications = n
}

// Unread returns the unread message count.
func (c *Conversation) Unread() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.unread
}

// IncUnread increments the unread count.
func (c *Conversation) IncUnread() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.unread++
}

// SetUnread sets the unread count.
func (c *Conversation) SetUnread(n int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.unread = n
}

// Modes returns the channel modes as a name→bool map.
func (c *Conversation) Modes() map[string]bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if len(c.modes) == 0 {
		return nil
	}
	res := make(map[string]bool, len(c.modes))
	maps.Copy(res, c.modes)
	return res
}

// UpdateModes parses an IRC mode string (e.g. "+nt", "-m") and merges it
// into the stored channel modes. Only modes present in channelModeNames
// are tracked.
func (c *Conversation) UpdateModes(modeStr string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.modes == nil {
		c.modes = make(map[string]bool)
	}

	add := true
	for i := 0; i < len(modeStr); i++ {
		ch := modeStr[i]
		switch ch {
		case '+':
			add = true
		case '-':
			add = false
		default:
			if name, ok := channelModeNames[ch]; ok {
				c.modes[name] = add
			}
		}
	}
}

// Info returns additional conversation info.
func (c *Conversation) Info() map[string]any {
	c.mu.RLock()
	defer c.mu.RUnlock()

	info := make(map[string]any)
	maps.Copy(info, c.info)
	return info
}

// SetInfo sets an info key.
func (c *Conversation) SetInfo(key string, value any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.info[key] = value
}

// Participants returns the list of participants.
func (c *Conversation) Participants() map[string]Participant {
	c.mu.RLock()
	defer c.mu.RUnlock()

	res := make(map[string]Participant, len(c.participants))
	maps.Copy(res, c.participants)
	return res
}

// AddParticipant adds or updates a participant.
func (c *Conversation) AddParticipant(p Participant) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.participants[p.Nick] = p
}

// RemoveParticipant removes a participant.
func (c *Conversation) RemoveParticipant(nick string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.participants, nick)
}

// ToData converts to serializable format.
func (c *Conversation) ToData(persist bool) ConversationData {
	c.mu.RLock()
	defer c.mu.RUnlock()

	data := ConversationData{
		ConnectionID:   c.connection.ID(),
		ConversationID: c.id,
		Name:           c.name,
		Topic:          c.topic,
		Frozen:         c.frozen,
		Notifications:  c.notifications,
		Unread:         c.unread,
		Info:           c.Info(),
		Participants:   c.Participants(),
	}

	if persist {
		data.Password = c.password
	}

	return data
}
