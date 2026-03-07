package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestEmbedHandler(t *testing.T) {
	t.Parallel()
	backend := test.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)
	// Replace the safe HTTP client with a plain one so the test server on
	// loopback (127.0.0.1) is not blocked by SSRF protection.
	h.EmbedClient.HTTPClient = &http.Client{Timeout: 5 * time.Second}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, err := w.Write([]byte(`<html><head><title>Test Page</title></head></html>`))
		if err != nil {
			t.Fatalf("Failed to write response: %v", err)
		}
	}))
	t.Cleanup(ts.Close)

	t.Run("Embed_Success", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequestWithContext(t.Context(), "GET", "/api/embed?url="+ts.URL, nil)
		w := httptest.NewRecorder()
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
		ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

		request := api.EmbedRequestObject{
			Params: api.EmbedParams{
				Url: ts.URL,
			},
		}

		resp, err := h.Embed(ctx, request)
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}

		if r, ok := resp.(api.Embed200JSONResponse); ok {
			if r["title"] != "Test Page" {
				t.Errorf("Expected title 'Test Page', got %q", r["title"])
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}

		if w.Header().Get("Cache-Control") != "max-age=600" {
			t.Errorf("Expected Cache-Control max-age=600, got %q", w.Header().Get("Cache-Control"))
		}
	})

	t.Run("Embed_Error", func(t *testing.T) {
		t.Parallel()
		request := api.EmbedRequestObject{
			Params: api.EmbedParams{
				Url: "http://invalid-domain-that-does-not-exist.test",
			},
		}

		resp, _ := h.Embed(context.Background(), request)
		if r, ok := resp.(api.Embed200JSONResponse); ok {
			if r["errors"] == nil {
				t.Error("Expected error list in response")
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})
}
