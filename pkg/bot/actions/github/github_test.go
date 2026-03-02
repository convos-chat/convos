package github

import (
	"testing"
)

func TestFormatGitHubMessage(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		payload  map[string]any
		expected string
	}{
		{
			name: "push",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"ref":        "refs/heads/master",
				"commits": []any{
					map[string]any{"message": "First commit\nSecond line"},
				},
			},
			expected: "[convos-chat/convos] jhthorsen pushed 1 commit(s) to master: First commit",
		},
		{
			name: "pull_request",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"action":     "opened",
				"pull_request": map[string]any{
					"number":   123,
					"title":    "Fix bug",
					"html_url": "https://github.com/convos-chat/convos/pull/123",
				},
			},
			expected: "[convos-chat/convos] jhthorsen opened pull request #123: Fix bug — https://github.com/convos-chat/convos/pull/123",
		},
		{
			name: "ping",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"zen":        "Keep it simple, stupid.",
			},
			expected: "[convos-chat/convos] GitHub ping: Keep it simple, stupid.",
		},
		{
			name: "issue_comment",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"sender":     map[string]any{"login": "jhthorsen"},
				"action":     "created",
				"issue":      map[string]any{"number": 456},
				"comment":    map[string]any{"html_url": "https://github.com/convos-chat/convos/issues/456#issuecomment-789"},
			},
			expected: "[convos-chat/convos] jhthorsen commented on issue #456: https://github.com/convos-chat/convos/issues/456#issuecomment-789",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, _ := formatGitHubMessage(tt.payload)
			if got != tt.expected {
				t.Errorf("formatGitHubMessage() = %q, want %q", got, tt.expected)
			}
		})
	}
}
