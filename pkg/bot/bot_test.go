package bot

import (
	"testing"

	"github.com/convos-chat/convos/pkg/core"
)

// mockAction is a minimal Action implementation for testing.
type mockAction struct {
	id             string
	registered     bool
	handleProvider string
	handlePayload  map[string]any
	handleResult   bool
}

func (a *mockAction) ID() string { return a.id }
func (a *mockAction) Register(m *Manager) {
	a.registered = true
}
func (a *mockAction) HandleWebhook(provider string, payload map[string]any) bool {
	a.handleProvider = provider
	a.handlePayload = payload
	return a.handleResult
}

func TestNewManager(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	if m == nil {
		t.Fatal("NewManager() returned nil")
	}
	if m.actions == nil {
		t.Error("actions map should be initialized")
	}
	if m.BotUser() != nil {
		t.Error("BotUser() should be nil initially")
	}
}

func TestRegisterAction(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	action := &mockAction{id: "test"}

	m.RegisterAction(action)

	if !action.registered {
		t.Error("action.Register should have been called")
	}

	m.mu.RLock()
	got, ok := m.actions["test"]
	m.mu.RUnlock()
	if !ok {
		t.Fatal("action not found in actions map")
	}
	if got.ID() != "test" {
		t.Errorf("registered action ID = %q, want %q", got.ID(), "test")
	}
}

func TestRegisterMultipleActions(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	a1 := &mockAction{id: "github"}
	a2 := &mockAction{id: "gitea"}

	m.RegisterAction(a1)
	m.RegisterAction(a2)

	m.mu.RLock()
	defer m.mu.RUnlock()
	if len(m.actions) != 2 {
		t.Errorf("len(actions) = %d, want 2", len(m.actions))
	}
}

func TestHandleWebhook_NoBotUser(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	action := &mockAction{id: "github", handleResult: true}
	m.RegisterAction(action)

	result := m.HandleWebhook("github", map[string]any{})
	if result {
		t.Error("HandleWebhook() should return false when no bot user")
	}
}

func TestHandleWebhook_MatchingProvider(t *testing.T) {
	t.Parallel()
	m := newManagerWithBotUser(t)
	action := &mockAction{id: "github", handleResult: true}
	m.RegisterAction(action)

	payload := map[string]any{"key": "value"}
	result := m.HandleWebhook("github", payload)
	if !result {
		t.Error("HandleWebhook() should return true when action handles it")
	}
	if action.handleProvider != "github" {
		t.Errorf("action received provider = %q, want %q", action.handleProvider, "github")
	}
}

func TestHandleWebhook_NoMatchingProvider(t *testing.T) {
	t.Parallel()
	m := newManagerWithBotUser(t)
	action := &mockAction{id: "github", handleResult: false}
	m.RegisterAction(action)

	result := m.HandleWebhook("unknown", map[string]any{})
	if result {
		t.Error("HandleWebhook() should return false when no action handles it")
	}
}

func TestHandleWebhook_FallbackToIterating(t *testing.T) {
	t.Parallel()
	m := newManagerWithBotUser(t)

	// Register action with id "github" but it won't handle "other"
	action := &mockAction{id: "github", handleResult: false}
	m.RegisterAction(action)

	// Register a catch-all action that handles anything
	catchAll := &mockAction{id: "catchall", handleResult: true}
	m.RegisterAction(catchAll)

	// Provider "other" won't match "github" or "catchall" by ID directly,
	// so it iterates all actions
	result := m.HandleWebhook("other", map[string]any{})
	if !result {
		t.Error("HandleWebhook() should return true when catch-all handles it")
	}
}

func TestRouteMessage_NoConfig(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	m.Config = nil

	result := m.RouteMessage("github", "test message", "push", nil)
	if result {
		t.Error("RouteMessage() should return false when Config is nil")
	}
}

func TestRouteMessage_NoMatchingAction(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	m.Config = &BotConfig{
		Actions: []ActionConfig{
			{Class: "Convos::Plugin::Bot::Action::Gitea"},
		},
	}

	result := m.RouteMessage("github", "test message", "push", map[string]any{})
	if result {
		t.Error("RouteMessage() should return false when no matching action class")
	}
}

func TestRouteMessage_MatchingActionNoRepos(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	m.Config = &BotConfig{
		Actions: []ActionConfig{
			{Class: "Convos::Plugin::Bot::Action::Github"},
		},
	}

	result := m.RouteMessage("github", "test message", "push", map[string]any{})
	if !result {
		t.Error("RouteMessage() should return true (silenced) when action matches but has no repos")
	}
}

func TestRouteMessage_MatchingRepoNoMatchingEvents(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	m.Config = &BotConfig{
		Actions: []ActionConfig{
			{
				Class: "Convos::Plugin::Bot::Action::Github",
				Repositories: map[string][]RepoRule{
					"convos-chat/convos": {
						{Events: []string{"issues"}, To: "conn/#chan"},
					},
				},
			},
		},
	}

	payload := map[string]any{
		"repository": map[string]any{"full_name": "convos-chat/convos"},
	}
	result := m.RouteMessage("github", "test message", "push", payload)
	if !result {
		t.Error("RouteMessage() should return true when repo matches (even if event doesn't)")
	}
}

func TestRouteMessage_UnknownRepo(t *testing.T) {
	t.Parallel()
	m := NewManager(nil)
	m.Config = &BotConfig{
		Actions: []ActionConfig{
			{
				Class: "Convos::Plugin::Bot::Action::Github",
				Repositories: map[string][]RepoRule{
					"convos-chat/convos": {
						{Events: []string{"push"}, To: "conn/#chan"},
					},
				},
			},
		},
	}

	payload := map[string]any{
		"repository": map[string]any{"full_name": "other/repo"},
	}
	result := m.RouteMessage("github", "test message", "push", payload)
	if !result {
		t.Error("RouteMessage() should return true (silenced) for unknown repo when action is configured")
	}
}

func TestFindRepoRules(t *testing.T) {
	t.Parallel()

	m := NewManager(nil)
	m.Config = &BotConfig{
		Actions: []ActionConfig{
			{
				Class: "Convos::Plugin::Bot::Action::Github",
				Repositories: map[string][]RepoRule{
					"convos-chat/convos": {
						{Events: []string{"push", "pull_request"}, To: "irc-libera/#convos"},
						{Events: []string{"issues"}, To: "irc-libera/#bugs"},
					},
				},
			},
		},
	}

	t.Run("matching repo", func(t *testing.T) {
		t.Parallel()
		payload := map[string]any{
			"repository": map[string]any{"full_name": "convos-chat/convos"},
		}
		rules, hasConfig := m.findRepoRules("github", payload)
		if !hasConfig {
			t.Error("hasConfig should be true")
		}
		if len(rules) != 2 {
			t.Errorf("len(rules) = %d, want 2", len(rules))
		}
	})

	t.Run("unknown repo", func(t *testing.T) {
		t.Parallel()
		payload := map[string]any{
			"repository": map[string]any{"full_name": "other/repo"},
		}
		rules, hasConfig := m.findRepoRules("github", payload)
		if !hasConfig {
			t.Error("hasConfig should be true")
		}
		if len(rules) != 0 {
			t.Errorf("len(rules) = %d, want 0", len(rules))
		}
	})

	t.Run("unknown action", func(t *testing.T) {
		t.Parallel()
		payload := map[string]any{}
		rules, hasConfig := m.findRepoRules("unknown", payload)
		if hasConfig {
			t.Error("hasConfig should be false for unknown action")
		}
		if rules != nil {
			t.Error("rules should be nil for unknown action")
		}
	})

	t.Run("missing repository in payload", func(t *testing.T) {
		t.Parallel()
		payload := map[string]any{}
		rules, hasConfig := m.findRepoRules("github", payload)
		if !hasConfig {
			t.Error("hasConfig should be true")
		}
		if len(rules) != 0 {
			t.Errorf("len(rules) = %d, want 0", len(rules))
		}
	})
}

// newManagerWithBotUser creates a Manager with a non-nil botUser for testing
// webhook dispatch logic without needing full infrastructure.
func newManagerWithBotUser(t *testing.T) *Manager {
	t.Helper()
	c := core.New(core.WithHome(t.TempDir()))
	m := NewManager(c)
	m.botUser = core.NewUser("bot@convos.chat", c)
	return m
}
