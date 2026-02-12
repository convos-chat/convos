package handler

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
)

func TestConversationHandlers(t *testing.T) {
	t.Parallel()

	setup := func() (*Handler, *core.User, *core.Conversation) {
		backend := core.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		h := NewHandler(c, nil, nil)

		user, _ := c.User("test@example.com")
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to create user: %v", err)
		}
		conn := irc.NewConnection("irc://irc.libera.chat", user)
		user.AddConnection(conn)
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.SetUnread(5)
		conv.SetTopic("Better group chat")

		if err := backend.SaveConnection(conn); err != nil {
			t.Fatalf("Failed to save connection: %v", err)
		}

		return h, user, conv
	}

	t.Run("ListConversations", func(t *testing.T) {
		t.Parallel()
		h, user, _ := setup()
		ctx := context.WithValue(context.Background(), CtxKeyUser, user)
		resp, _ := h.ListConversations(ctx, api.ListConversationsRequestObject{})
		r, ok := resp.(api.ListConversations200JSONResponse)
		if !ok {
			t.Fatalf("Unexpected response type: %T", resp)
		}

		if len(*r.Conversations) != 1 {
			t.Fatalf("Expected 1 conversation, got %d", len(*r.Conversations))
		}

		c0 := (*r.Conversations)[0]
		if c0.ConversationId != "#convos" {
			t.Errorf("Expected #convos, got %q", c0.ConversationId)
		}
		if *c0.Topic != "Better group chat" {
			t.Errorf("Expected topic, got %q", *c0.Topic)
		}
		if c0.Unread != 5 {
			t.Errorf("Expected 5 unread, got %d", c0.Unread)
		}
	})

	t.Run("MarkConversationAsRead", func(t *testing.T) {
		t.Parallel()
		h, user, conv := setup()
		ctx := context.WithValue(context.Background(), CtxKeyUser, user)
		request := api.MarkConversationAsReadRequestObject{
			ConnectionId:   "irc-libera",
			ConversationId: "#convos",
		}

		_, _ = h.MarkConversationAsRead(ctx, request)
		if conv.Unread() != 0 {
			t.Errorf("Expected 0 unread, got %d", conv.Unread())
		}
	})

	t.Run("ConversationMessages_Empty", func(t *testing.T) {
		t.Parallel()
		h, user, _ := setup()
		ctx := context.WithValue(context.Background(), CtxKeyUser, user)
		request := api.ConversationMessagesRequestObject{
			ConnectionId:   "irc-libera",
			ConversationId: "#convos",
			Params:         api.ConversationMessagesParams{},
		}

		resp, _ := h.ConversationMessages(ctx, request)
		if r, ok := resp.(api.ConversationMessages200JSONResponse); ok {
			if len(*r.Messages) != 0 {
				t.Errorf("Expected 0 messages, got %d", len(*r.Messages))
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})
}
