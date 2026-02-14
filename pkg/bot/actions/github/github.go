// Package github implements a bot action that listens for GitHub webhook events
package github

import (
	"fmt"
	"log/slog"
	"strings"

	"github.com/convos-chat/convos/pkg/bot"
	"github.com/convos-chat/convos/pkg/core"
)

// Action implements the GitHub bot action.
type Action struct {
	manager *bot.Manager
}

// NewAction creates a new GitHub action.
func NewAction() *Action {
	return &Action{}
}

// ID returns the action ID.
func (a *Action) ID() string {
	return "github"
}

func (a *Action) Register(m *bot.Manager) {
	a.manager = m
}

func (a *Action) HandleWebhook(provider string, payload map[string]any) bool {
	if provider != "github" {
		return false
	}

	msg, event := formatGitHubMessage(payload)
	if msg == "" {
		return true
	}

	if a.manager.RouteMessage(a.ID(), msg, event, payload) {
		return true
	}

	a.broadcastMessage(msg)
	return true
}

func (a *Action) broadcastMessage(message string) {
	botUser := a.manager.BotUser()
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
					slog.Warn("GitHub bot: Failed to send message", "connection", conn.ID(), "conversation", conv.ID(), "error", err)
				} else {
					sent = true
				}
			}
		}
	}

	if !sent {
		slog.Warn("GitHub bot: No connected channels found for bot user. Please ensure the bot is connected and has joined channels.")
	}
}

// formatGitHubMessage formats a GitHub webhook event into an IRC message.
func formatGitHubMessage(payload map[string]any) (string, string) {
	get := func(keys ...string) string {
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

	repo := get("repository", "full_name")
	sender := get("sender", "login")

	if commits, ok := payload["commits"].([]any); ok {
		return formatPushMessage(repo, sender, commits, get), "push"
	}

	if _, ok := payload["pull_request"]; ok {
		action := get("action")
		num := get("pull_request", "number")
		title := get("pull_request", "title")
		url := get("pull_request", "html_url")
		if sender == "dependabot[bot]" || sender == "renovate[bot]" {
			return "", "pull_request"
		}
		return fmt.Sprintf("[%s] %s %s pull request #%s: %s — %s", repo, sender, action, num, title, url), "pull_request"
	}

	if _, ok := payload["issue"]; ok {
		if _, ok := payload["comment"]; ok {
			action := get("action")
			if action != "created" {
				return "", "issue_comment"
			}
			num := get("issue", "number")
			url := get("comment", "html_url")
			return fmt.Sprintf("[%s] %s commented on issue #%s: %s", repo, sender, num, url), "issue_comment"
		}
		action := get("action")
		num := get("issue", "number")
		title := get("issue", "title")
		url := get("issue", "html_url")
		return fmt.Sprintf("[%s] %s %s issue #%s: %s — %s", repo, sender, action, num, title, url), "issues"
	}

	if zen := get("zen"); zen != "" {
		return fmt.Sprintf("[%s] GitHub ping: %s", repo, zen), "ping"
	}

	if refType := get("ref_type"); refType != "" {
		ref := get("ref")
		if _, ok := payload["master_branch"]; ok {
			return fmt.Sprintf("[%s] %s created %s %s", repo, sender, refType, ref), "create"
		}
	}

	return "", "unknown"
}

func formatPushMessage(repo, sender string, commits []any, get func(...string) string) string {
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
