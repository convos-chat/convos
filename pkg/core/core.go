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
	"time"

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
	mu                        sync.RWMutex
	Home                      string
	Backend                   Backend
	Settings                  *Settings
	users                     map[string]*User
	profiles                  map[string]*ConnectionProfile
	EventEmitter              *EventEmitter
	provider                  ConnectionProvider
	ready                     bool
	log                       *slog.Logger
	ConnectDelay              time.Duration
	DefaultMaxBulkMessageSize int
	DefaultMaxMessageLength   int
	DefaultServiceAccounts    []string
}

// Option configures a Core instance.
type Option func(*Core)

// WithHome sets the home directory for data storage.
func WithHome(home string) Option {
	return func(c *Core) {
		c.Home = home
	}
}

// WithBackend sets the storage backend.
func WithBackend(backend Backend) Option {
	return func(c *Core) {
		c.Backend = backend
	}
}

func WithProfileDefaults(maxBulkSize, maxMessageLength int, serviceAccounts []string) Option {
	return func(c *Core) {
		c.DefaultMaxMessageLength = maxMessageLength
		c.DefaultMaxBulkMessageSize = maxBulkSize
		c.DefaultServiceAccounts = serviceAccounts
	}
}

// WithConnectionProvider sets the connection provider.
func WithConnectionProvider(provider ConnectionProvider) Option {
	return func(c *Core) {
		c.provider = provider
	}
}

// WithConnectDelay sets the stagger delay between auto-connect attempts per host at startup.
func WithConnectDelay(d time.Duration) Option {
	return func(c *Core) {
		c.ConnectDelay = d
	}
}

// New creates a new Core instance with the given options.
func New(opts ...Option) *Core {
	c := &Core{
		users:        make(map[string]*User),
		profiles:     make(map[string]*ConnectionProfile),
		EventEmitter: NewEventEmitter(),
		log:          slog.Default(),
	}

	for _, opt := range opts {
		opt(c)
	}

	// Default home from environment
	if c.Home == "" {
		c.Home = os.Getenv("CONVOS_HOME")
		if c.Home == "" {
			c.Home = filepath.Join(os.Getenv("HOME"), ".convos")
		}
	}

	if c.Backend == nil {
		panic("No backend configured. Please provide a storage backend using WithBackend option.")
	}

	c.Settings = &Settings{core: c}

	return c
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

// RolesForNewUser returns ["admin"] if no users exist yet, otherwise an empty slice.
// Used by auto-registration flows to give the first registered user admin privileges.
func (c *Core) RolesForNewUser() []string {
	if len(c.Users()) == 0 {
		return []string{"admin"}
	}
	return []string{}
}

// ConnectionProfile returns a connection profile for the given URL.
func (c *Core) ConnectionProfile(u *url.URL) *ConnectionProfile {
	c.mu.Lock()
	defer c.mu.Unlock()

	id := strings.ToLower(u.Scheme + "-" + PrettyConnectionName(u.Host))
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
	defaultConn := c.Settings.DefaultConnection()
	if defaultConn == "" {
		return
	}

	defaultURL, err := url.Parse(defaultConn)
	if err != nil {
		return
	}

	defaultID := strings.ToLower(defaultURL.Scheme + "-" + PrettyConnectionName(defaultURL.Host))
	if id == defaultID {
		return
	}

	if defaultProfile, ok := c.profiles[defaultID]; ok {
		p.ApplyDefaults(defaultProfile)
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
	return c.Backend.DeleteUser(user)
}

// nextUID returns the next available user ID. Must be called with mu held.
func (c *Core) nextUID() int {
	uid := 1
	for _, u := range c.users {
		if u.uid >= uid {
			uid = u.uid + 1
		}
	}
	return uid
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

func (c *Core) Initialize() error {
	settingsData, err := c.Backend.LoadSettings()
	if err != nil {
		c.log.Error("Failed to load settings", "error", err)
	} else {
		c.Settings.FromData(settingsData)
	}

	profiles, err := c.Backend.LoadConnectionProfiles()
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

	usersData, err := c.Backend.LoadUsers()
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
		user.ignoreMasks = userData.IgnoreMasks
		if user.ignoreMasks == nil {
			user.ignoreMasks = make(map[string]string)
		}

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

	c.ready = true
	return nil
}

// Start initializes the core if not ready and auto-connects
func (c *Core) Start() error {
	if !c.Ready() {
		if err := c.Initialize(); err != nil {
			return err
		}
	}
	c.log.Info("Core starting", "users", len(c.users))

	// Auto-connect connections that want to be connected, staggered per host.
	hostIdx := make(map[string]int)
	for _, user := range c.users {
		for _, conn := range user.Connections() {
			if conn.WantedState() == StateConnected {
				host := conn.URL().Host
				delay := time.Duration(hostIdx[host]) * c.ConnectDelay
				hostIdx[host]++
				go func(cn Connection, d time.Duration) {
					if d > 0 {
						time.Sleep(d)
					}
					if err := cn.Connect(); err != nil {
						c.log.Error("Failed to auto-connect", "connection", cn.ID(), "error", err)
					}
				}(conn, delay)
			}
		}
	}

	return nil
}
