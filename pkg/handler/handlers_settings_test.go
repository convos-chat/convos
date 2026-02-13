package handler

import (
	"context"
	"errors"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/auth"
)

func TestSettingsHandlers(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *Handler, *core.User, *core.User) {
		backend := core.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

		admin, _ := c.User("admin@example.com")
		admin.GiveRole("admin")
		if err := admin.Save(); err != nil {
			t.Fatalf("Failed to save admin user: %v", err)
		}

		user, _ := c.User("user@example.com")
		if err := user.Save(); err != nil {
			t.Fatalf("Failed to save regular user: %v", err)
		}
		return c, h, admin, user
	}

	t.Run("GetSettings", func(t *testing.T) {
		t.Parallel()
		c, h, _, user := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		c.Settings().SetOrganizationName("Convos")
		resp, _ := h.GetSettings(ctx, api.GetSettingsRequestObject{})
		if r, ok := resp.(api.GetSettings200JSONResponse); ok {
			if *r.OrganizationName != "Convos" {
				t.Errorf("Expected organization Convos, got %q", *r.OrganizationName)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("UpdateSettings_Admin", func(t *testing.T) {
		t.Parallel()
		c, h, admin, _ := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
		newName := "My Org"
		request := api.UpdateSettingsRequestObject{
			Body: &api.UpdateSettingsJSONRequestBody{
				OrganizationName: &newName,
			},
		}

		resp, _ := h.UpdateSettings(ctx, request)
		if r, ok := resp.(api.UpdateSettings200JSONResponse); ok {
			if *r.OrganizationName != newName {
				t.Errorf("Expected organization %q, got %q", newName, *r.OrganizationName)
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}

		if c.Settings().OrganizationName() != newName {
			t.Errorf("Core settings not updated, got %q", c.Settings().OrganizationName())
		}
	})

	t.Run("UpdateSettings_NonAdmin", func(t *testing.T) {
		t.Parallel()
		_, h, _, user := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		failName := "Hack"
		request := api.UpdateSettingsRequestObject{
			Body: &api.UpdateSettingsJSONRequestBody{
				OrganizationName: &failName,
			},
		}

		resp, err := h.UpdateSettings(ctx, request)
		if err != nil {
			if errors.Is(err, ErrForbidden) {
				return
			}
			t.Fatalf("Unexpected error: %v", err)
		}

		if r, ok := resp.(api.UpdateSettings200JSONResponse); ok {
			if *r.OrganizationName == failName {
				t.Error("Settings should NOT have been updated by non-admin")
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})
}
