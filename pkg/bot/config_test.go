package bot

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIDFromClass(t *testing.T) {
	t.Parallel()
	tests := []struct {
		class    string
		expected string
	}{
		{"Convos::Plugin::Bot::Action::Github", "github"},
		{"Convos::Plugin::Bot::Action::Gitea", "gitea"},
		{"Convos::Plugin::Bot::Action::SomeCustom", "somecustom"},
		{"Simple", "simple"},
	}

	for _, tt := range tests {
		t.Run(tt.class, func(t *testing.T) {
			t.Parallel()
			got := IDFromClass(tt.class)
			if got != tt.expected {
				t.Errorf("IDFromClass(%q) = %q, want %q", tt.class, got, tt.expected)
			}
		})
	}
}

func TestLoadConfig(t *testing.T) {
	t.Parallel()

	t.Run("valid config", func(t *testing.T) {
		t.Parallel()
		dir := t.TempDir()
		cfgPath := filepath.Join(dir, "bot.yaml")
		content := `
generic:
  password: secret123
  reply_delay: 1.5
actions:
  - class: "Convos::Plugin::Bot::Action::Github"
    enabled: true
    repositories:
      convos-chat/convos:
        - events: [push, pull_request]
          to: "irc-libera/chat/#convos"
connections:
  - url: irc://irc.libera.chat:6697
    wanted_state: connected
    conversations:
      "#convos":
        state: join
      "#test":
        password: chanpass
        state: join
`
		if err := os.WriteFile(cfgPath, []byte(content), 0600); err != nil {
			t.Fatal(err)
		}

		cfg, err := LoadConfig(cfgPath)
		if err != nil {
			t.Fatalf("LoadConfig() error = %v", err)
		}

		if cfg.Generic.Password != "secret123" {
			t.Errorf("Generic.Password = %q, want %q", cfg.Generic.Password, "secret123")
		}
		if cfg.Generic.ReplyDelay != 1.5 {
			t.Errorf("Generic.ReplyDelay = %f, want %f", cfg.Generic.ReplyDelay, 1.5)
		}
		if len(cfg.Actions) != 1 {
			t.Fatalf("len(Actions) = %d, want 1", len(cfg.Actions))
		}
		if cfg.Actions[0].Class != "Convos::Plugin::Bot::Action::Github" {
			t.Errorf("Actions[0].Class = %q, want Github class", cfg.Actions[0].Class)
		}
		if len(cfg.Actions[0].Repositories) != 1 {
			t.Fatalf("len(Repositories) = %d, want 1", len(cfg.Actions[0].Repositories))
		}
		rules := cfg.Actions[0].Repositories["convos-chat/convos"]
		if len(rules) != 1 {
			t.Fatalf("len(rules) = %d, want 1", len(rules))
		}
		if rules[0].To != "irc-libera/chat/#convos" {
			t.Errorf("rules[0].To = %q, want %q", rules[0].To, "irc-libera/chat/#convos")
		}
		if len(rules[0].Events) != 2 {
			t.Errorf("len(rules[0].Events) = %d, want 2", len(rules[0].Events))
		}

		if len(cfg.Connections) != 1 {
			t.Fatalf("len(Connections) = %d, want 1", len(cfg.Connections))
		}
		if cfg.Connections[0].URL != "irc://irc.libera.chat:6697" {
			t.Errorf("Connections[0].URL = %q", cfg.Connections[0].URL)
		}
		if cfg.Connections[0].WantedState != "connected" {
			t.Errorf("Connections[0].WantedState = %q", cfg.Connections[0].WantedState)
		}
		if len(cfg.Connections[0].Conversations) != 2 {
			t.Errorf("len(Conversations) = %d, want 2", len(cfg.Connections[0].Conversations))
		}
		convos := cfg.Connections[0].Conversations["#convos"]
		const stateJoin = "join"
		if convos.State != stateJoin {
			t.Errorf("convos state = %q, want %q", convos.State, stateJoin)
		}
		test := cfg.Connections[0].Conversations["#test"]
		if test.Password != "chanpass" {
			t.Errorf("test password = %q, want chanpass", test.Password)
		}

		if cfg.Seen.IsZero() {
			t.Error("Seen should be set from file mod time")
		}
	})

	t.Run("file not found", func(t *testing.T) {
		t.Parallel()
		_, err := LoadConfig("/nonexistent/path/bot.yaml")
		if err == nil {
			t.Error("LoadConfig() should return error for missing file")
		}
	})

	t.Run("invalid yaml", func(t *testing.T) {
		t.Parallel()
		dir := t.TempDir()
		cfgPath := filepath.Join(dir, "bot.yaml")
		if err := os.WriteFile(cfgPath, []byte("{{invalid yaml"), 0600); err != nil {
			t.Fatal(err)
		}

		_, err := LoadConfig(cfgPath)
		if err == nil {
			t.Error("LoadConfig() should return error for invalid YAML")
		}
	})

	t.Run("empty config", func(t *testing.T) {
		t.Parallel()
		dir := t.TempDir()
		cfgPath := filepath.Join(dir, "bot.yaml")
		if err := os.WriteFile(cfgPath, []byte(""), 0600); err != nil {
			t.Fatal(err)
		}

		cfg, err := LoadConfig(cfgPath)
		if err != nil {
			t.Fatalf("LoadConfig() error = %v", err)
		}
		if len(cfg.Actions) != 0 {
			t.Errorf("len(Actions) = %d, want 0", len(cfg.Actions))
		}
		if len(cfg.Connections) != 0 {
			t.Errorf("len(Connections) = %d, want 0", len(cfg.Connections))
		}
	})
}
