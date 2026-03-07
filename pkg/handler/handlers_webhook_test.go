package handler

import (
	"context"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestWebhookIPValidation(t *testing.T) {
	t.Parallel()
	backend := test.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	nets := ParseWebhookNetworks("127.0.0.0/24")
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nets)

	t.Run("AllowedIP", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/webhook/github", nil)
		req.RemoteAddr = "127.0.0.1:1234"
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

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
		req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/webhook/github", nil)
		req.RemoteAddr = "192.168.1.1:1234"
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

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
