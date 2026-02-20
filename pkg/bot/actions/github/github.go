// Package github implements a bot action that listens for GitHub webhook events
package github

import (
	"fmt"

	"github.com/convos-chat/convos/pkg/bot"
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

	a.manager.BroadcastMessage("GitHub", msg)
	return true
}

// formatGitHubMessage formats a GitHub webhook event into an IRC message.
func formatGitHubMessage(payload map[string]any) (string, string) {
	get := bot.PayloadGetter(payload)

	repo := get("repository", "full_name")
	sender := get("sender", "login")

	if commits, ok := payload["commits"].([]any); ok {
		return bot.FormatPushMessage(repo, sender, commits, get), "push"
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

