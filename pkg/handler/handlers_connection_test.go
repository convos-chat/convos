package handler

import (
	"context"
	"errors"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
	"github.com/convos-chat/convos/pkg/test"
	"github.com/gorilla/sessions"
)

const testServer = "irc-libera"

func TestConnectionHandlers(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *Handler, *core.User) {
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		store := sessions.NewCookieStore([]byte("secret"))
		h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

		user, _ := c.User("test@example.com")
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to create user: %v", err)
		}
		return c, h, user
	}

	t.Run("CreateConnection_Unauthorized", func(t *testing.T) {
		t.Parallel()
		_, h, _ := setup()
		req := httptest.NewRequest("POST", "/api/connections", nil)
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)

		request := api.CreateConnectionRequestObject{
			Body: &api.CreateConnectionJSONRequestBody{
				Url: "irc://irc.libera.chat",
			},
		}

		resp, err := h.CreateConnection(ctx, request)
		if err != nil {
			if errors.Is(err, ErrUnauthorized) {
				return
			}
			t.Fatalf("Unexpected error: %v", err)
		}

		if _, ok := resp.(api.CreateConnection401JSONResponse); !ok {
			t.Errorf("Expected api.CreateConnection401JSONResponse, got %T", resp)
		}
	})

	t.Run("CreateConnection_Success", func(t *testing.T) {
		t.Parallel()
		_, h, user := setup()
		req := httptest.NewRequest("POST", "/api/connections", nil)
		ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
		ctx = context.WithValue(ctx, core.CtxKeyUser, user)

		request := api.CreateConnectionRequestObject{
			Body: &api.CreateConnectionJSONRequestBody{
				Url: "irc://irc.libera.chat",
			},
		}

		resp, _ := h.CreateConnection(ctx, request)
		if r, ok := resp.(api.CreateConnection200JSONResponse); ok {
			if r.Url != "irc://irc.libera.chat?nick=test" {
				t.Errorf("Expected URL with default nick, got %q", r.Url)
			}
			if r.ConnectionId != testServer {
				t.Errorf("Expected connection_id irc-libera, got %q", r.ConnectionId)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("ListConnections", func(t *testing.T) {
		t.Parallel()
		c, h, user := setup()
		conn := irc.NewConnection("irc://irc.libera.chat", user)
		user.AddConnection(conn)
		if err := c.Backend.SaveConnection(conn); err != nil {
			t.Fatalf("Failed to save connection: %v", err)
		}

		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		resp, _ := h.ListConnections(ctx, api.ListConnectionsRequestObject{})
		if r, ok := resp.(api.ListConnections200JSONResponse); ok {
			if len(*r.Connections) != 1 {
				t.Errorf("Expected 1 connection, got %d", len(*r.Connections))
			} else if (*r.Connections)[0].ConnectionId != testServer {
				t.Errorf("Expected connection_id irc-libera, got %q", (*r.Connections)[0].ConnectionId)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("UpdateConnection", func(t *testing.T) {
		t.Parallel()
		c, h, user := setup()
		conn := irc.NewConnection("irc://irc.libera.chat", user)
		user.AddConnection(conn)
		if err := c.Backend.SaveConnection(conn); err != nil {
			t.Fatalf("Failed to save connection: %v", err)
		}

		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		cmds := []string{"/msg NickServ identify pass"}
		request := api.UpdateConnectionRequestObject{
			ConnectionId: testServer,
			Body: &api.UpdateConnectionJSONRequestBody{
				OnConnectCommands: &cmds,
			},
		}

		resp, _ := h.UpdateConnection(ctx, request)
		if r, ok := resp.(api.UpdateConnection200JSONResponse); ok {
			if len(*r.OnConnectCommands) != 1 || (*r.OnConnectCommands)[0] != cmds[0] {
				t.Errorf("Expected updated commands, got %v", *r.OnConnectCommands)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("RemoveConnection", func(t *testing.T) {
		t.Parallel()
		c, h, user := setup()
		conn := irc.NewConnection("irc://irc.libera.chat", user)
		user.AddConnection(conn)
		if err := c.Backend.SaveConnection(conn); err != nil {
			t.Fatalf("Failed to save connection: %v", err)
		}

		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		request := api.RemoveConnectionRequestObject{
			ConnectionId: testServer,
		}

		resp, _ := h.RemoveConnection(ctx, request)
		if r, ok := resp.(api.RemoveConnection200JSONResponse); ok {
			if *r.Message != "Connection removed" {
				t.Errorf("Expected success message, got %q", *r.Message)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}

		if len(user.Connections()) != 0 {
			t.Error("Connection should have been removed from user")
		}
	})
}
