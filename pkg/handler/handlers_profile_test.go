package handler

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestProfileHandlers(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *Handler, *core.User) {
		backend := test.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

		admin, _ := c.User("admin@example.com")
		admin.GiveRole("admin")
		_ = admin.Save()
		return c, h, admin
	}

	t.Run("ListConnectionProfiles_Default", func(t *testing.T) {
		t.Parallel()
		_, h, _ := setup()
		resp, _ := h.ListConnectionProfiles(context.Background(), api.ListConnectionProfilesRequestObject{})
		r, ok := resp.(api.ListConnectionProfiles200JSONResponse)
		if !ok {
			t.Fatalf("Unexpected response type: %T", resp)
		}
		if len(*r.Profiles) != 1 {
			t.Errorf("Expected 1 default profile, got %d", len(*r.Profiles))
		} else {
			p0 := (*r.Profiles)[0]
			if p0.Url != "irc://irc.libera.chat:6697" {
				t.Errorf("Expected Libera URL, got %q", p0.Url)
			}
		}
	})

	t.Run("SaveConnectionProfile_Admin", func(t *testing.T) {
		t.Parallel()
		c, h, admin := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
		url := "irc://irc.oftc.net"
		isDefault := true
		request := api.SaveConnectionProfileRequestObject{
			Body: &api.ConnectionProfile{
				Url:       url,
				IsDefault: &isDefault,
			},
		}

		resp, _ := h.SaveConnectionProfile(ctx, request)
		if r, ok := resp.(api.SaveConnectionProfile200JSONResponse); ok {
			if r.Url != url {
				t.Errorf("Expected URL %q, got %q", url, r.Url)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}

		// Verify settings update
		if c.Settings().DefaultConnection() != url {
			t.Errorf("Default connection setting not updated, got %q", c.Settings().DefaultConnection())
		}
	})

	t.Run("RemoveConnectionProfile_Admin", func(t *testing.T) {
		t.Parallel()
		c, h, admin := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
		// ID foroftc is irc-oftc
		request := api.RemoveConnectionProfileRequestObject{
			Id: "irc-oftc",
		}

		resp, _ := h.RemoveConnectionProfile(ctx, request)
		if _, ok := resp.(api.RemoveConnectionProfile200JSONResponse); !ok {
			t.Errorf("Unexpected response type: %T", resp)
		}

		// Verify deletion
		profiles, _ := c.Backend().LoadConnectionProfiles()
		if len(profiles) != 0 {
			t.Error("Profile should have been deleted")
		}
	})
}
