package gitea

import (
	"fmt"
	"log/slog"
	"strings"

	"github.com/convos-chat/convos/pkg/bot"
)

// Action implements the Gitea/Forgejo bot action.
type Action struct {
	manager *bot.Manager
}

// NewAction creates a new Gitea action.
func NewAction() *Action {
	return &Action{}
}

// ID returns the action ID.
func (a *Action) ID() string {
	return "gitea"
}

func (a *Action) Register(m *bot.Manager) {
	a.manager = m
}

func (a *Action) HandleWebhook(provider string, payload map[string]any) bool {
	// Support both "gitea" and "codeberg" (which is forgejo/gitea based)
	if provider != "gitea" && provider != "codeberg" && provider != "forgejo" {
		return false
	}

	msg, event := formatGiteaMessage(payload)
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
		if string(conn.State()) != "connected" {
			continue
		}
		for _, conv := range conn.Conversations() {
			if strings.HasPrefix(conv.ID(), "#") {
				if err := conn.Send(conv.ID(), message); err != nil {
					slog.Warn("Gitea bot: Failed to send message", "connection", conn.ID(), "conversation", conv.ID(), "error", err)
				} else {
					sent = true
				}
			}
		}
	}

	if !sent {
		slog.Warn("Gitea bot: No connected channels found for bot user. Please ensure the bot is connected and has joined channels.")
	}
}

// formatGiteaMessage formats a Gitea webhook event into an IRC message.
func formatGiteaMessage(payload map[string]any) (string, string) {
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
	// Gitea uses "pusher" for pushes, "sender" for others, but sender is usually available.
	sender := get("sender", "login")
	if sender == "" {
		sender = get("pusher", "username")
	}

	if commits, ok := payload["commits"].([]any); ok {
		return formatPushMessage(repo, sender, commits, get), "push"
	}

	if _, ok := payload["pull_request"]; ok {
		action := get("action")
		num := get("pull_request", "number")
		title := get("pull_request", "title")
		url := get("pull_request", "html_url")
		return fmt.Sprintf("[%s] %s %s pull request #%s: %s — %s", repo, sender, action, num, title, url), "pull_request"
	}

	if _, ok := payload["issue"]; ok {
		if _, ok := payload["comment"]; ok {
			// Issue Comment
			num := get("issue", "number")
			url := get("comment", "html_url")
			return fmt.Sprintf("[%s] %s commented on issue #%s: %s", repo, sender, num, url), "issue_comment"
		}
		// Issue
		action := get("action")
		num := get("issue", "number")
		title := get("issue", "title")
		url := get("issue", "html_url")
		return fmt.Sprintf("[%s] %s %s issue #%s: %s — %s", repo, sender, action, num, title, url), "issues"
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
