// Package bot implements the bot manager and related functionality for Convos.
package bot

import (
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/convos-chat/convos/pkg/core"
)

// Action defines the interface for bot actions.
type Action interface {
	// ID returns the unique identifier for this action (e.g., "github").
	ID() string
	// Register is called when the action is initialized.
	Register(manager *Manager)
	// HandleWebhook handles a webhook event. Returns true if handled.
	HandleWebhook(provider string, payload map[string]any) bool
}

// Manager manages the bot user and actions.
type Manager struct {
	core       *core.Core
	actions    map[string]Action
	mu         sync.RWMutex
	botUser    *core.User
	Config     *BotConfig
	configFile string
}

func NewManager(c *core.Core) *Manager {
	return &Manager{
		core:    c,
		actions: make(map[string]Action),
	}
}

// Start initializes the bot user and starts event listeners.
func (m *Manager) Start() {
	email := os.Getenv("CONVOS_BOT_EMAIL")
	if email == "" {
		return
	}

	m.configFile = filepath.Join(m.core.Home(), email, "bot.yaml")
	m.registerUser()
	m.loadConfig()
	m.startEventListeners()
	slog.Info("Bot email configured, starting bot manager", "email", email, "cfg", m.Config)

	go m.configLoop()
}

func (m *Manager) configLoop() {
	interval := 10 * time.Second
	if s := os.Getenv("CONVOS_BOT_LOAD_INTERVAL"); s != "" {
		if d, err := strconv.Atoi(s); err == nil {
			interval = time.Duration(d) * time.Second
		}
	}

	m.loadConfig()

	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for range ticker.C {
		m.loadConfig()
	}
}

func (m *Manager) loadConfig() {
	if m.configFile == "" {
		return
	}

	if _, err := os.Stat(m.configFile); os.IsNotExist(err) {
		return
	}

	cfg, err := LoadConfig(m.configFile)
	if err != nil {
		slog.Error("Failed to load bot config", "file", m.configFile, "error", err)
		return
	}

	m.mu.Lock()
	currentSeen := time.Time{}
	if m.Config != nil {
		currentSeen = m.Config.Seen
	}
	m.mu.Unlock()

	if !cfg.Seen.After(currentSeen) {
		return
	}

	slog.Info("Reloading bot config", "file", m.configFile)

	m.mu.Lock()
	m.Config = cfg
	m.mu.Unlock()

	// Apply config
	if cfg.Generic.Password != "" {
		if err := m.botUser.SetPassword(cfg.Generic.Password); err != nil {
			slog.Error("Failed to set bot password from config", "error", err)
		} else {
			if err := m.botUser.Save(); err != nil {
				slog.Error("Failed to save bot user after password update", "error", err)
			}
		}
	}

	m.ensureConnections()
}

func (m *Manager) ensureConnections() {
	if m.botUser == nil || m.Config == nil {
		return
	}

	for _, connCfg := range m.Config.Connections {
		if connCfg.URL == "" {
			continue
		}
		if connCfg.WantedState == "" {
			connCfg.WantedState = string(core.StateConnected)
		}

		conn := m.ensureConnection(connCfg)
		if conn == nil {
			continue
		}

		m.ensureConnectionState(conn, connCfg.WantedState)
		m.ensureConversations(conn, connCfg.Conversations)
	}
}

func (m *Manager) ensureConnection(connCfg ConnectionConfig) core.Connection {
	// Parse URL to generate ID
	_, err := url.Parse(connCfg.URL)
	if err != nil {
		slog.Warn("Invalid connection URL in bot config", "url", connCfg.URL, "error", err)
		return nil
	}

	// Use a dummy BaseConnection to calculate ID consistently with Core
	dummy := core.NewBaseConnection(connCfg.URL, m.botUser)
	connID := dummy.ID()

	conn := m.botUser.GetConnection(connID)
	if conn == nil {
		conn = m.core.NewConnection(connCfg.URL, m.botUser)
		if conn == nil {
			slog.Warn("Failed to create connection from config", "url", connCfg.URL)
			return nil
		}
		m.botUser.AddConnection(conn)
		slog.Info("Created bot connection", "id", connID, "url", connCfg.URL)
	}
	return conn
}

func (m *Manager) ensureConnectionState(conn core.Connection, wantedState string) {
	wanted := core.StateConnected
	if wantedState == string(core.StateDisconnected) {
		wanted = core.StateDisconnected
	}

	conn.SetWantedState(wanted)
	if wanted == core.StateConnected && conn.State() == core.StateDisconnected {
		go func() {
			if err := conn.Connect(); err != nil {
				slog.Error("Failed to connect bot", "connection", conn.ID(), "error", err)
			}
		}()
	} else if wanted == core.StateDisconnected && conn.State() == core.StateConnected {
		go func() {
			if err := conn.Disconnect(); err != nil {
				slog.Error("Failed to disconnect bot", "connection", conn.ID(), "error", err)
			}
		}()
	}
}

func (m *Manager) ensureConversations(conn core.Connection, conversations map[string]ConversationConfig) {
	for convName, convCfg := range conversations {
		m.ensureConversation(conn, convName, convCfg)
	}
}

func (m *Manager) ensureConversation(conn core.Connection, convName string, convCfg ConversationConfig) {
	state := convCfg.State
	if state == "" {
		state = "join"
	}

	conv := conn.GetConversation(convName)

	switch state {
	case "join":
		m.joinConversation(conn, conv, convName, convCfg.Password)
	case "part":
		m.partConversation(conn, conv, convName)
	}
}

func (m *Manager) joinConversation(conn core.Connection, conv *core.Conversation, name, password string) {
	if conv != nil && conv.Frozen() == "" {
		return
	}

	cmd := fmt.Sprintf("/join %s", name)
	if password != "" {
		cmd += " " + password
	}
	if err := conn.Send("", cmd); err != nil {
		slog.Warn("Failed to send join command", "connection", conn.ID(), "channel", name, "error", err)
	}
}

func (m *Manager) partConversation(conn core.Connection, conv *core.Conversation, name string) {
	if conv == nil || conv.Frozen() != "" {
		return
	}

	if err := conn.Send("", fmt.Sprintf("/part %s", name)); err != nil {
		slog.Warn("Failed to send part command", "connection", conn.ID(), "channel", name, "error", err)
	}
}

func (m *Manager) registerUser() {
	email := os.Getenv("CONVOS_BOT_EMAIL")
	if email == "" {
		return
	}

	user := m.core.GetUser(email)
	if user == nil {
		m.createNewBotUser(email)
	} else if !user.HasRole("bot") {
		user.GiveRole("bot")
		if err := user.Save(); err != nil {
			slog.Error("Failed to save bot user role", "error", err)
		}
	}

	m.botUser = user
}

func (m *Manager) createNewBotUser(email string) {
	user := core.NewUser(email, m.core)
	user.GiveRole("bot")
	if err := user.SetPassword(fmt.Sprintf("%d", time.Now().UnixNano())); err != nil {
		slog.Error("Failed to set bot password", "error", err)
	}
	if err := user.Save(); err != nil {
		slog.Error("Failed to save bot user", "error", err)
		return
	}
	slog.Info("Created bot user", "email", email)
}

func (m *Manager) startEventListeners() {
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			m.checkConnections()
		}
	}()
}

func (m *Manager) checkConnections() {
	if m.botUser == nil {
		return
	}

	for _, conn := range m.botUser.Connections() {
		if conn.State() != core.StateConnected {
			continue
		}

		if ok := m.checkAndApplyBotMode(conn); ok {
			slog.Debug("Checked bot mode", "connection", conn.ID())
		}
	}
}

func (m *Manager) checkAndApplyBotMode(conn core.Connection) bool {
	info := conn.Info()
	botMode, ok := info["bot"]

	if !ok {
		return false
	}

	modeChar := "B"
	if s, ok := botMode.(string); ok && s != "" {
		modeChar = s
	}

	if info["bot_mode_set"] != nil {
		return true
	}

	if currentMode, ok := info["mode"].(string); ok && strings.Contains(currentMode, modeChar) {
		conn.SetInfo("bot_mode_set", true)
		return true
	}

	if err := conn.Send("", fmt.Sprintf("/mode %s +%s", conn.Nick(), modeChar)); err != nil {
		slog.Warn("Failed to send bot mode command", "connection", conn.ID(), "error", err)
	} else {
		conn.SetInfo("bot_mode_set", true)
		slog.Info("Applied bot mode", "connection", conn.ID(), "mode", "+"+modeChar)
	}
	return true
}

func (m *Manager) RegisterAction(a Action) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.actions[a.ID()] = a
	a.Register(m)
}

func (m *Manager) HandleWebhook(provider string, payload map[string]any) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.botUser == nil {
		return false
	}

	if action, ok := m.actions[provider]; ok {
		return action.HandleWebhook(provider, payload)
	}

	for _, action := range m.actions {
		if action.HandleWebhook(provider, payload) {
			return true
		}
	}

	return false
}

func (m *Manager) BotUser() *core.User {
	return m.botUser
}

// BroadcastMessage sends a message to all connected channels of the bot user.
// actionName is used in log messages (e.g. "GitHub", "Gitea").
func (m *Manager) BroadcastMessage(actionName, message string) {
	botUser := m.BotUser()
	if botUser == nil {
		return
	}

	sent := false
	for _, conn := range botUser.Connections() {
		if conn.State() != core.StateConnected {
			continue
		}
		for _, conv := range conn.Conversations() {
			if strings.HasPrefix(conv.ID(), "#") {
				if err := conn.Send(conv.ID(), message); err != nil {
					slog.Warn(actionName+" bot: Failed to send message", "connection", conn.ID(), "conversation", conv.ID(), "error", err)
				} else {
					sent = true
				}
			}
		}
	}

	if !sent {
		slog.Warn(actionName + " bot: No connected channels found for bot user. Please ensure the bot is connected and has joined channels.")
	}
}

// PayloadGetter returns a helper that navigates nested keys in a webhook payload map,
// returning the string form of the value or "" if any key is missing or the path is invalid.
func PayloadGetter(payload map[string]any) func(...string) string {
	return func(keys ...string) string {
		val := payload
		for i, k := range keys {
			v, ok := val[k]
			if !ok {
				return ""
			}
			if i == len(keys)-1 {
				return fmt.Sprintf("%v", v)
			}
			if m, ok := v.(map[string]any); ok {
				val = m
			} else {
				return ""
			}
		}
		return ""
	}
}

// FormatPushMessage formats a git push event into a human-readable IRC message.
// get is a helper that navigates nested map keys, as provided by each webhook formatter.
func FormatPushMessage(repo, sender string, commits []any, get func(...string) string) string {
	ref := get("ref")
	branch := strings.TrimPrefix(ref, "refs/heads/")
	msg := fmt.Sprintf("[%s] %s pushed %d commit(s) to %s", repo, sender, len(commits), branch)
	if len(commits) > 0 {
		if first, ok := commits[0].(map[string]any); ok {
			if cm, ok := first["message"].(string); ok {
				cm = strings.SplitN(cm, "\n", 2)[0]
				msg += fmt.Sprintf(": %s", cm)
			}
		}
	}
	return msg
}

// RouteMessage routes a formatted message based on the bot configuration.
// Returns true if the message was handled (even if silently ignored by filter).
// Returns false if no configuration was found for the action (caller should decide fallback).
func (m *Manager) RouteMessage(actionID, msg, event string, payload map[string]any) bool {
	if m.Config == nil {
		return false
	}

	rules, hasConfig := m.findRepoRules(actionID, payload)

	if !hasConfig {
		return false // Fall back to broadcast
	}

	if len(rules) == 0 {
		return true // Configured but no rules for this repo -> Silence
	}

	for _, rule := range rules {
		m.processRoutingRule(rule, event, msg)
	}

	return true
}

func (m *Manager) findRepoRules(actionID string, payload map[string]any) ([]RepoRule, bool) {
	for _, actionCfg := range m.Config.Actions {
		if IDFromClass(actionCfg.Class) == actionID {
			if actionCfg.Repositories == nil {
				return nil, true
			}
			// Get repo name
			repo, _ := payload["repository"].(map[string]any)
			if repoName, ok := repo["full_name"].(string); ok {
				if r, ok := actionCfg.Repositories[repoName]; ok {
					return r, true
				}
			}
			return nil, true
		}
	}
	return nil, false
}

func (m *Manager) processRoutingRule(rule RepoRule, event, msg string) {
	match := slices.Contains(rule.Events, event)
	if !match {
		return
	}

	parts := strings.SplitN(rule.To, "/", 2)
	if len(parts) != 2 {
		slog.Warn("Invalid routing rule target", "to", rule.To)
		return
	}
	connID, convID := parts[0], parts[1]

	conn := m.botUser.GetConnection(connID)
	if conn == nil || conn.State() != core.StateConnected {
		slog.Warn("Bot not connected to target", "connection", connID)
		return
	}

	if err := conn.Send(convID, msg); err != nil {
		slog.Warn("Failed to send routed message", "target", rule.To, "error", err)
	}
}
