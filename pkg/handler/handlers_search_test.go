package handler

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
)

func TestSearchMessages(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, nil, nil)

	user, _ := c.User("test@example.com")
	if err := user.Save(); err != nil {
		t.Fatalf("Failed to save user: %v", err)
	}

	t.Run("Search_Empty", func(t *testing.T) {
		t.Parallel()
		ctx := context.WithValue(context.Background(), CtxKeyUser, user)
		match := "foo"
		resp, _ := h.SearchMessages(ctx, api.SearchMessagesRequestObject{
			Params: api.SearchMessagesParams{
				Match: &match,
			},
		})
		if r, ok := resp.(api.SearchMessages200JSONResponse); ok {
			if len(*r.Messages) != 0 {
				t.Error("Expected 0 messages for empty search")
			}
		}
	})
}
