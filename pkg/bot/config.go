package bot

import (
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// BotConfig represents the configuration in bot.yaml.
type BotConfig struct {
	Generic     GenericConfig      `yaml:"generic"`
	Actions     []ActionConfig     `yaml:"actions"`
	Connections []ConnectionConfig `yaml:"connections"`
	Seen        time.Time          `yaml:"-"` // Last modification time
}

type GenericConfig struct {
	Password   string  `yaml:"password"`
	ReplyDelay float64 `yaml:"reply_delay"`
}

type ActionConfig struct {
	Class        string                `yaml:"class"`
	Enabled      *bool                 `yaml:"enabled"`
	Repositories map[string][]RepoRule `yaml:"repositories"`
	Settings     map[string]any        `yaml:",inline"`
}

type RepoRule struct {
	Events []string `yaml:"events"`
	To     string   `yaml:"to"`
}

type ConnectionConfig struct {
	URL           string                        `yaml:"url"`
	WantedState   string                        `yaml:"wanted_state"`
	Actions       map[string]map[string]any     `yaml:"actions"`
	Conversations map[string]ConversationConfig `yaml:"conversations"`
}

type ConversationConfig struct {
	Password string                    `yaml:"password"`
	State    string                    `yaml:"state"`
	Actions  map[string]map[string]any `yaml:"actions"`
}

// LoadConfig loads the bot configuration from the given path.
func LoadConfig(path string) (*BotConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var cfg BotConfig
	if err = yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	info, err := os.Stat(path)
	if err == nil {
		cfg.Seen = info.ModTime()
	}

	return &cfg, nil
}

// IDFromClass returns the simplified action ID from a Perl class name.
// e.g., "Convos::Plugin::Bot::Action::Github" -> "github"
func IDFromClass(class string) string {
	parts := strings.Split(class, "::")
	return strings.ToLower(parts[len(parts)-1])
}
