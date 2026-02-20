// Package gitea implements a bot action for Gitea/Forgejo webhooks.
package gitea

import (
	"fmt"

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

	a.manager.BroadcastMessage("Gitea", msg)
	return true
}

// formatGiteaMessage formats a Gitea webhook event into an IRC message.
func formatGiteaMessage(payload map[string]any) (string, string) {
	get := bot.PayloadGetter(payload)

	repo := get("repository", "full_name")
	// Gitea uses "pusher" for pushes, "sender" for others, but sender is usually available.
	sender := get("sender", "login")
	if sender == "" {
		sender = get("pusher", "username")
	}

	if commits, ok := payload["commits"].([]any); ok {
		return bot.FormatPushMessage(repo, sender, commits, get), "push"
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

