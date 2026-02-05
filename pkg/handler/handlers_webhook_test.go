package handler

import (
	"context"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
)

func TestWebhookIPValidation(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	nets := ParseWebhookNetworks("127.0.0.0/24")
	h := NewHandler(c, nil, nets)

	t.Run("AllowedIP", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequest("POST", "/api/webhook/github", nil)
		req.RemoteAddr = "127.0.0.1:1234"
		ctx := context.WithValue(context.Background(), CtxKeyRequest, req)

		body := api.WebhookJSONRequestBody{"foo": "bar"}
		request := api.WebhookRequestObject{
			ProviderName: "github",
			Body:         &body,
		}

		resp, err := h.Webhook(ctx, request)
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if r, ok := resp.(api.Webhook200JSONResponse); ok {
			if _, rejected := r["errors"]; rejected {
				t.Errorf("Webhook unexpectedly rejected: %v", r["errors"])
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("RejectedIP", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequest("POST", "/api/webhook/github", nil)
		req.RemoteAddr = "192.168.1.1:1234"
		ctx := context.WithValue(context.Background(), CtxKeyRequest, req)

		body := api.WebhookJSONRequestBody{"foo": "bar"}
		request := api.WebhookRequestObject{
			ProviderName: "github",
			Body:         &body,
		}

		resp, err := h.Webhook(ctx, request)
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if r, ok := resp.(api.Webhook200JSONResponse); ok {
			if _, rejected := r["errors"]; !rejected {
				t.Error("Webhook should have been rejected but wasn't")
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})
}

func TestFormatGitHubMessage(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name     string
		event    string
		payload  map[string]any
		expected string
	}{
		{
			name:  "push",
			event: "push",
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
			name:  "pull_request",
			event: "pull_request",
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
			name:  "ping",
			event: "ping",
			payload: map[string]any{
				"repository": map[string]any{"full_name": "convos-chat/convos"},
				"zen":        "Keep it simple, stupid.",
			},
			expected: "[convos-chat/convos] GitHub ping: Keep it simple, stupid.",
		},
		{
			name:  "issue_comment",
			event: "issue_comment",
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
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got := formatGitHubMessage(tt.event, tt.payload)
			if got != tt.expected {
				t.Errorf("formatGitHubMessage() = %q, want %q", got, tt.expected)
			}
		})
	}
}
