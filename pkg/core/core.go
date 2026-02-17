// Package core implements the core business logic for Convos.
// It mirrors the structure of Convos::Core from the Perl implementation.
package core

import (
	"log/slog"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/SherClockHolmes/webpush-go"
)

type CtxKey string

const (
	CtxKeyRequest        CtxKey = "http.Request"
	CtxKeyResponseWriter CtxKey = "http.ResponseWriter"
	CtxKeyUser           CtxKey = "core.User"
)

// ConnectionProvider creates a Connection from a raw URL and user.
type ConnectionProvider interface {
	NewConnection(rawURL string, user *User) (Connection, error)
}

// Core is the main entry point for Convos business logic.
// It manages users, connection profiles, and the storage backend.
type Core struct {
	mu       sync.RWMutex
	home     string
	backend  Backend
	settings *Settings
	users    map[string]*User
	profiles map[string]*ConnectionProfile
	events   *EventEmitter
	provider ConnectionProvider
	ready    bool
	log      *slog.Logger
	getenv   func(string) string
}

// Option configures a Core instance.
type Option func(*Core)

// WithHome sets the home directory for data storage.
func WithHome(home string) Option {
	return func(c *Core) {
		c.home = home
	}
}

// WithBackend sets the storage backend.
func WithBackend(backend Backend) Option {
	return func(c *Core) {
		c.backend = backend
	}
}

// WithConnectionProvider sets the connection provider.
func WithConnectionProvider(provider ConnectionProvider) Option {
	return func(c *Core) {
		c.provider = provider
	}
}

// WithLogger sets the logger.
func WithLogger(log *slog.Logger) Option {
	return func(c *Core) {
		c.log = log
	}
}

// New creates a new Core instance with the given options.
func New(opts ...Option) *Core {
	c := &Core{
		users:    make(map[string]*User),
		profiles: make(map[string]*ConnectionProfile),
		events:   NewEventEmitter(),
		log:      slog.Default(),
		getenv:   os.Getenv,
	}

	for _, opt := range opts {
		opt(c)
	}

	// Default home from environment
	if c.home == "" {
		c.home = os.Getenv("CONVOS_HOME")
		if c.home == "" {
			c.home = filepath.Join(os.Getenv("HOME"), ".convos")
		}
	}

	// Default backend
	if c.backend == nil {
		c.backend = NewMemoryBackend()
	}

	c.settings = &Settings{core: c}

	return c
}

// Home returns the home directory path.
func (c *Core) Home() string {
	return c.home
}

// Backend returns the storage backend.
func (c *Core) Backend() Backend {
	return c.backend
}

// Settings returns the core settings.
func (c *Core) Settings() *Settings {
	return c.settings
}

// Events returns the event emitter.
func (c *Core) Events() *EventEmitter {
	return c.events
}

// Ready returns whether the core has finished loading initial data.
func (c *Core) Ready() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.ready
}

// User returns an existing user or creates a new one.
func (c *Core) User(email string) (*User, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	email = normalizeEmail(email)
	if user, ok := c.users[email]; ok {
		return user, nil
	}

	user := NewUser(email, c)
	user.uid = c.nextUID()
	c.users[email] = user
	return user, nil
}

// GetUser returns a user by email, or nil if not found.
func (c *Core) GetUser(email string) *User {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.users[normalizeEmail(email)]
}

// Users returns all users.
func (c *Core) Users() []*User {
	c.mu.RLock()
	defer c.mu.RUnlock()

	users := make([]*User, 0, len(c.users))
	for _, u := range c.users {
		users = append(users, u)
	}
	return users
}

// ConnectionProfile returns a connection profile for the given URL.
func (c *Core) ConnectionProfile(u *url.URL) *ConnectionProfile {
	c.mu.Lock()
	defer c.mu.Unlock()

	id := strings.ToLower(u.Scheme + "-" + prettyConnectionName(u.Host))
	if p, ok := c.profiles[id]; ok {
		return p
	}

	p := NewConnectionProfile(u.String(), c)
	c.applyDefaultSettings(p, id)

	c.profiles[id] = p
	return p
}

// applyDefaultSettings applies settings from the default connection profile if applicable.
// c.mu must be held.
func (c *Core) applyDefaultSettings(p *ConnectionProfile, id string) {
	defaultConn := c.settings.DefaultConnection()
	if defaultConn == "" {
		return
	}

	defaultURL, err := url.Parse(defaultConn)
	if err != nil {
		return
	}

	defaultID := strings.ToLower(defaultURL.Scheme + "-" + prettyConnectionName(defaultURL.Host))
	if id == defaultID {
		return
	}

	if defaultProfile, ok := c.profiles[defaultID]; ok {
		p.ApplyDefaults(defaultProfile)
		p.LoadEnv() // Re-apply env vars to override defaults
	}
}

// ConnectionProfiles returns all stored connection profiles.
func (c *Core) ConnectionProfiles() []*ConnectionProfile {
	c.mu.RLock()
	defer c.mu.RUnlock()

	profiles := make([]*ConnectionProfile, 0, len(c.profiles))
	for _, p := range c.profiles {
		profiles = append(profiles, p)
	}
	return profiles
}

// RemoveUser removes a user from the core.
func (c *Core) RemoveUser(email string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	email = normalizeEmail(email)
	user, ok := c.users[email]
	if !ok {
		return nil
	}

	// Disconnect all connections (ignore errors during cleanup)
	for _, conn := range user.Connections() {
		_ = conn.Disconnect()
	}

	delete(c.users, email)
	return c.backend.DeleteUser(user)
}

// nextUID returns the next available user ID. Must be called with mu held.
func (c *Core) nextUID() int {
	uid := len(c.users) + 1
	for {
		taken := false
		for _, u := range c.users {
			if u.uid == uid {
				taken = true
				break
			}
		}
		if !taken {
			return uid
		}
		uid++
	}
}

// NewConnection creates a connection using the registered provider.
// Returns nil if no provider is registered or the scheme is not supported.
func (c *Core) NewConnection(rawURL string, user *User) Connection {
	if c.provider == nil {
		return nil
	}
	conn, err := c.provider.NewConnection(rawURL, user)
	if err != nil {
		c.log.Warn("Failed to create connection", "url", rawURL, "error", err)
		return nil
	}
	return conn
}

// Start initializes the core by loading users and their connections.
func (c *Core) Start() error {
	c.mu.RLock()
	if c.ready {
		c.mu.RUnlock()
		return nil
	}
	c.mu.RUnlock()

	// Load settings from backend
	settingsData, err := c.backend.LoadSettings()
	if err != nil {
		c.log.Error("Failed to load settings", "error", err)
	} else {
		c.settings.FromData(settingsData)
	}

	// Load connection profiles from backend
	profiles, err := c.backend.LoadConnectionProfiles()
	if err != nil {
		c.log.Error("Failed to load connection profiles", "error", err)
	} else {
		// Populate profiles without holding the lock for the whole operation,
		// but we need them in c.profiles for user.loadConnections() to work.
		c.mu.Lock()
		for _, profileData := range profiles {
			p := NewConnectionProfile(profileData.URL, c)
			p.FromData(profileData)
			c.profiles[p.ID()] = p
		}
		c.mu.Unlock()
	}

	// Load users from backend
	usersData, err := c.backend.LoadUsers()
	if err != nil {
		return err
	}

	// Prepare users and connections without holding c.mu to avoid deadlocks
	// when NewConnection calls c.ConnectionProfile (which locks c.mu).
	var loadedUsers []*User
	for _, userData := range usersData {
		user := NewUser(userData.Email, c)
		user.password = userData.Password
		user.roles = userData.Roles
		user.uid = userData.UID
		user.registered = userData.Registered
		user.subscriptions = userData.Subscriptions
		if user.subscriptions == nil {
			user.subscriptions = make(map[string]webpush.Subscription)
		}

		// Load connections for user
		if err := user.loadConnections(); err != nil {
			c.log.Error("Failed to load connections", "user", user.Email(), "error", err)
		}
		loadedUsers = append(loadedUsers, user)
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	for _, user := range loadedUsers {
		c.users[user.ID()] = user
	}

	// Ensure first user has admin role (back compat)
	if len(c.users) > 0 {
		var firstUser *User
		hasAdmin := false
		for _, u := range c.users {
			if firstUser == nil {
				firstUser = u
			}
			if u.HasRole("admin") {
				hasAdmin = true
				break
			}
		}
		if !hasAdmin && firstUser != nil {
			firstUser.GiveRole("admin")
		}
	}

	c.ready = true
	c.log.Info("Core started", "users", len(c.users))

	// Auto-connect connections that want to be connected
	for _, user := range c.users {
		for _, conn := range user.Connections() {
			if conn.WantedState() == StateConnected {
				go func(cn Connection) {
					if err := cn.Connect(); err != nil {
						c.log.Error("Failed to auto-connect", "connection", cn.ID(), "error", err)
					}
				}(conn)
			}
		}
	}

	return nil
}
