package gitea

import (
	"testing"
)

func TestFormatGiteaMessage(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name      string
		payload   map[string]any
		expected  string
		eventType string
	}{
		{
			name: "push",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"ref":        "refs/heads/main",
				"commits": []any{
					map[string]any{"message": "Add feature\nMore details"},
					map[string]any{"message": "Fix test"},
				},
			},
			expected:  "[convos-chat/convos] jhthorsen pushed 2 commit(s) to main: Add feature",
			eventType: "push",
		},
		{
			name: "push with pusher fallback",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"pusher":     map[string]any{"username": "batman"},
				"ref":        "refs/heads/develop",
				"commits": []any{
					map[string]any{"message": "Initial commit"},
				},
			},
			expected:  "[convos-chat/convos] batman pushed 1 commit(s) to develop: Initial commit",
			eventType: "push",
		},
		{
			name: "pull_request opened",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"action":     "opened",
				"pull_request": map[string]any{
					"number":   42,
					"title":    "Add dark mode",
					"html_url": "https://codeberg.org/convos-chat/convos/pulls/42",
				},
			},
			expected:  "[convos-chat/convos] jhthorsen opened pull request #42: Add dark mode — https://codeberg.org/convos-chat/convos/pulls/42",
			eventType: "pull_request",
		},
		{
			name: "issue opened",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"action":     "opened",
				"issue": map[string]any{
					"number":   10,
					"title":    "Bug report",
					"html_url": "https://codeberg.org/convos-chat/convos/issues/10",
				},
			},
			expected:  "[convos-chat/convos] jhthorsen opened issue #10: Bug report — https://codeberg.org/convos-chat/convos/issues/10",
			eventType: "issues",
		},
		{
			name: "issue_comment",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"issue":      map[string]any{"number": 10},
				"comment":    map[string]any{"html_url": "https://codeberg.org/convos-chat/convos/issues/10#issuecomment-100"},
			},
			expected:  "[convos-chat/convos] jhthorsen commented on issue #10: https://codeberg.org/convos-chat/convos/issues/10#issuecomment-100",
			eventType: "issue_comment",
		},
		{
			name: "unknown event",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
			},
			expected:  "",
			eventType: "unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, eventType := formatGiteaMessage(tt.payload)
			if got != tt.expected {
				t.Errorf("formatGiteaMessage() message = %q, want %q", got, tt.expected)
			}
			if eventType != tt.eventType {
				t.Errorf("formatGiteaMessage() event = %q, want %q", eventType, tt.eventType)
			}
		})
	}
}

func TestHandleWebhook_ProviderFiltering(t *testing.T) {
	t.Parallel()

	action := NewAction()

	tests := []struct {
		provider string
		handled  bool
	}{
		{"gitea", true},
		{"codeberg", true},
		{"forgejo", true},
		{"github", false},
		{"unknown", false},
	}

	for _, tt := range tests {
		t.Run(tt.provider, func(t *testing.T) {
			t.Parallel()
			// Without a manager, HandleWebhook will panic on route/broadcast,
			// but we can test the provider check by passing an unknown event
			// that produces an empty message (so it returns true without routing).
			payload := map[string]any{
				"repository": map[string]any{"full_name": "test/repo"},
			}
			got := action.HandleWebhook(tt.provider, payload)
			if tt.handled && !got {
				t.Errorf("HandleWebhook(%q) = false, want true", tt.provider)
			}
			if !tt.handled && got {
				t.Errorf("HandleWebhook(%q) = true, want false", tt.provider)
			}
		})
	}
}
