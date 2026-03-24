package core

import (
	"log/slog"
	"maps"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/convos-chat/convos/pkg/password"
)

// User represents a Convos user.
type User struct {
	mu                sync.RWMutex
	Core              *Core
	email             string
	password          string
	roles             []string
	uid               int
	registered        time.Time
	remoteAddress     string
	highlightKeywords []string
	ignoreMasks       map[string]string // label (nick as typed) → "*!ident@host"; label used only for /unignore lookup, not matching
	unread            int
	connections       map[string]Connection
	subscriptions     map[string]webpush.Subscription
}

// UserData represents serialized user data for storage.
type UserData struct {
	Email             string                          `json:"email"`
	Password          string                          `json:"password,omitempty"`
	Roles             []string                        `json:"roles"`
	UID               int                             `json:"uid,string"`
	Registered        time.Time                       `json:"registered"`
	RemoteAddress     string                          `json:"remote_address"`
	HighlightKeywords []string                        `json:"highlight_keywords"`
	IgnoreMasks       map[string]string               `json:"ignore_masks,omitempty"`
	Unread            int                             `json:"unread"`
	Subscriptions     map[string]webpush.Subscription `json:"subscriptions,omitempty"`
}

// NewUser creates a new User instance.
func NewUser(email string, core *Core) *User {
	return &User{
		Core:              core,
		email:             normalizeEmail(email),
		roles:             []string{},
		registered:        time.Now().UTC().Truncate(time.Second),
		remoteAddress:     "127.0.0.1",
		highlightKeywords: []string{},
		ignoreMasks:       make(map[string]string),
		connections:       make(map[string]Connection),
		subscriptions:     make(map[string]webpush.Subscription),
	}
}

// Email returns the user's email address.
func (u *User) Email() string { return rGet(&u.mu, &u.email) }

// ID returns the unique identifier for this user (lowercase email).
func (u *User) ID() string { return rGet(&u.mu, &u.email) }

// UID returns the numeric user ID.
func (u *User) UID() int { return rGet(&u.mu, &u.uid) }

// SetUID sets the numeric user ID.
func (u *User) SetUID(uid int) { wSet(&u.mu, &u.uid, uid) }

// Password returns the hashed password.
func (u *User) Password() string { return rGet(&u.mu, &u.password) }

// SetPassword hashes and sets the user's password.
func (u *User) SetPassword(plain string) error {
	hash, err := password.GenerateHash(plain)
	if err != nil {
		return err
	}
	u.mu.Lock()
	defer u.mu.Unlock()
	u.password = hash
	return nil
}

// ValidatePassword checks if the plain password matches the stored hash.
func (u *User) ValidatePassword(plain string) bool {
	u.mu.RLock()
	defer u.mu.RUnlock()

	if u.password == "" || plain == "" {
		return false
	}
	valid, _ := password.ComparePassword(plain, u.password)
	return valid
}

// Roles returns the user's roles.
func (u *User) Roles() []string {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return slices.Clone(u.roles)
}

// HasRole checks if the user has a specific role.
func (u *User) HasRole(role string) bool {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return slices.Contains(u.roles, role)
}

// GiveRole adds a role to the user.
func (u *User) GiveRole(role string) {
	u.mu.Lock()
	defer u.mu.Unlock()
	if !slices.Contains(u.roles, role) {
		u.roles = append(u.roles, role)
		slices.Sort(u.roles)
	}
}

// TakeRole removes a role from the user.
func (u *User) TakeRole(role string) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.roles = slices.DeleteFunc(u.roles, func(r string) bool { return r == role })
}

// Registered returns when the user was registered.
func (u *User) Registered() time.Time { return rGet(&u.mu, &u.registered) }

// RemoteAddress returns the last known remote address.
func (u *User) RemoteAddress() string { return rGet(&u.mu, &u.remoteAddress) }

// SetRemoteAddress sets the last known remote address.
func (u *User) SetRemoteAddress(addr string) { wSet(&u.mu, &u.remoteAddress, addr) }

// HighlightKeywords returns keywords that trigger highlights.
func (u *User) HighlightKeywords() []string {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return slices.Clone(u.highlightKeywords)
}

// SetHighlightKeywords sets keywords that trigger highlights.
func (u *User) SetHighlightKeywords(keywords []string) { wSet(&u.mu, &u.highlightKeywords, keywords) }

// AddIgnoreMask stores a mask for later removal. nick is a user-supplied label
// mask must be in "*!ident@host" form. Thread-safe.
func (u *User) AddIgnoreMask(nick, mask string) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.ignoreMasks[nick] = mask
}

// RemoveIgnoreMask removes the ignore entry for nick. Thread-safe.
func (u *User) RemoveIgnoreMask(nick string) {
	u.mu.Lock()
	defer u.mu.Unlock()
	delete(u.ignoreMasks, nick)
}

// IgnoreMasks returns a copy of the ignore map. Thread-safe.
func (u *User) IgnoreMasks() map[string]string {
	u.mu.RLock()
	defer u.mu.RUnlock()
	cp := make(map[string]string, len(u.ignoreMasks))
	maps.Copy(cp, u.ignoreMasks)
	return cp
}

// IsIgnored returns true if *!ident@host matches any stored ignore mask.
// Masks use simple glob matching (* and ?). Both sides are lowercased.
// Returns false immediately when ident or host is empty (server-sourced message).
func (u *User) IsIgnored(nick, ident, host string) bool {
	if ident == "" || host == "" {
		return false
	}
	candidate := strings.ToLower(nick + "!" + ident + "@" + host)
	u.mu.RLock()
	defer u.mu.RUnlock()
	for _, mask := range u.ignoreMasks {
		match, err := filepath.Match(strings.ToLower(mask), candidate)
		if match && err == nil {
			return true
		}
	}
	return false
}

// Unread returns the number of unread notifications.
func (u *User) Unread() int { return rGet(&u.mu, &u.unread) }

// SetUnread sets the number of unread notifications.
func (u *User) SetUnread(n int) { wSet(&u.mu, &u.unread, n) }

// AddSubscription adds a Web Push subscription.
func (u *User) AddSubscription(sub webpush.Subscription) {
	u.mu.Lock()
	defer u.mu.Unlock()
	if u.subscriptions == nil {
		u.subscriptions = make(map[string]webpush.Subscription)
	}
	u.subscriptions[sub.Endpoint] = sub
}

// RemoveSubscription removes a Web Push subscription.
func (u *User) RemoveSubscription(endpoint string) {
	u.mu.Lock()
	defer u.mu.Unlock()
	delete(u.subscriptions, endpoint)
}

// Subscriptions returns all Web Push subscriptions.
func (u *User) Subscriptions() []webpush.Subscription {
	u.mu.RLock()
	defer u.mu.RUnlock()
	subs := make([]webpush.Subscription, 0, len(u.subscriptions))
	for _, sub := range u.subscriptions {
		subs = append(subs, sub)
	}
	return subs
}

// AddConnection adds a connection to the user.
func (u *User) AddConnection(conn Connection) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.connections[conn.ID()] = conn
}

// GetConnection returns a connection by ID.
func (u *User) GetConnection(id string) Connection {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return u.connections[strings.ToLower(id)]
}

// Connections returns all connections.
func (u *User) Connections() []Connection {
	u.mu.RLock()
	defer u.mu.RUnlock()

	conns := make([]Connection, 0, len(u.connections))
	for _, c := range u.connections {
		conns = append(conns, c)
	}
	return conns
}

// RemoveConnection removes a connection.
func (u *User) RemoveConnection(id string) error {
	u.mu.Lock()
	id = strings.ToLower(id)
	conn, ok := u.connections[id]
	if !ok {
		u.mu.Unlock()
		return nil
	}

	delete(u.connections, id)
	u.mu.Unlock()

	// Disconnect and delete outside the lock to avoid deadlock
	if err := conn.Disconnect(); err != nil {
		slog.Warn("Failed to disconnect connection", "id", id, "err", err)
	}
	return u.Core.Backend.DeleteConnection(conn)
}

// EmitEvent emits an event to all subscribers for this user.
func (u *User) EmitEvent(event Event) {
	u.Core.EventEmitter.EmitUser(u.ID(), event)
}

// Save persists the user to storage.
func (u *User) Save() error {
	return u.Core.Backend.SaveUser(u)
}

// ToData converts the user to a serializable format.
func (u *User) ToData(includePassword bool) UserData {
	u.mu.RLock()
	defer u.mu.RUnlock()

	data := UserData{
		Email:             u.email,
		Roles:             slices.Clone(u.roles),
		UID:               u.uid,
		Registered:        u.registered,
		RemoteAddress:     u.remoteAddress,
		HighlightKeywords: slices.Clone(u.highlightKeywords),
		Unread:            u.unread,
		Subscriptions:     make(map[string]webpush.Subscription, len(u.subscriptions)),
	}
	maps.Copy(data.Subscriptions, u.subscriptions)
	data.IgnoreMasks = make(map[string]string, len(u.ignoreMasks))
	maps.Copy(data.IgnoreMasks, u.ignoreMasks)

	if includePassword {
		data.Password = u.password
	}
	return data
}

// loadConnections loads connections from the backend.
func (u *User) loadConnections() error {
	conns, err := u.Core.Backend.LoadConnections(u)
	if err != nil {
		return err
	}

	// Create connections without holding the user lock to avoid deadlock
	// when NewConnection calls back into User methods (e.g. Email)
	createdConns := make([]Connection, 0)
	for _, connData := range conns {
		conn := u.Core.NewConnection(connData.URL, u)
		if conn == nil {
			slog.Warn("No provider registered for connection URL", "url", connData.URL)
			continue
		}
		conn.SetName(connData.Name)
		conn.SetWantedState(connData.WantedState)
		conn.SetOnConnectCommands(connData.OnConnectCommands)
		for k, v := range connData.Info {
			conn.SetInfo(k, v)
		}

		// Load conversations for connection
		for _, convData := range connData.Conversations {
			conv := NewConversation(convData.Name, conn)
			conv.SetTopic(convData.Topic)
			conv.SetPassword(convData.Password)
			conn.AddConversation(conv)
		}
		createdConns = append(createdConns, conn)
	}

	u.mu.Lock()
	defer u.mu.Unlock()

	for _, conn := range createdConns {
		u.connections[conn.ID()] = conn
	}

	return nil
}

// normalizeEmail normalizes an email address to lowercase.
func normalizeEmail(email string) string {
	return strings.TrimSpace(strings.ToLower(email))
}
