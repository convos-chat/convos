// Package core implements the core business logic for Convos.
// It mirrors the structure of Convos::Core from the Perl implementation.
package core

import (
	"log/slog"
	"os"
	"path/filepath"
	"sync"
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
	events   *EventEmitter
	provider ConnectionProvider
	ready    bool
	log      *slog.Logger
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
		users:  make(map[string]*User),
		events: NewEventEmitter(),
		log:    slog.Default(),
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
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.ready {
		return nil
	}

	// Load settings from backend
	settingsData, err := c.backend.LoadSettings()
	if err != nil {
		c.log.Error("Failed to load settings", "error", err)
	} else {
		c.settings.FromData(settingsData)
	}

	// Load users from backend
	users, err := c.backend.LoadUsers()
	if err != nil {
		return err
	}

	for _, userData := range users {
		user := NewUser(userData.Email, c)
		user.password = userData.Password
		user.roles = userData.Roles
		user.uid = userData.UID
		user.registered = userData.Registered
		c.users[user.ID()] = user

		// Load connections for user
		if err := user.loadConnections(); err != nil {
			c.log.Error("Failed to load connections", "user", user.Email(), "error", err)
		}
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
