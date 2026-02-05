package core

import (
	"net/url"
	"testing"
)

func TestSettings(t *testing.T) {
	t.Parallel()

	setup := func() (*MemoryBackend, *Settings) {
		backend := NewMemoryBackend()
		c := New(WithBackend(backend))
		s := c.Settings()
		return backend, s
	}

	t.Run("BaseURL", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		u, _ := url.Parse("https://convos.chat")
		s.SetBaseURL(u)
		if s.BaseURL().String() != "https://convos.chat" {
			t.Errorf("BaseURL() = %v, want %v", s.BaseURL(), u)
		}
	})

	t.Run("OpenToPublic", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		s.SetOpenToPublic(true)
		if !s.OpenToPublic() {
			t.Error("OpenToPublic() should be true")
		}
	})

	t.Run("Contact", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		val := "mailto:admin@example.com"
		s.SetContact(val)
		if s.Contact() != val {
			t.Errorf("Contact() = %q, want %q", s.Contact(), val)
		}
	})

	t.Run("DefaultConnection", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		val := "irc://irc.libera.chat"
		s.SetDefaultConnection(val)
		if s.DefaultConnection() != val {
			t.Errorf("DefaultConnection() = %q, want %q", s.DefaultConnection(), val)
		}
	})

	t.Run("ForcedConnection", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		s.SetForcedConnection(true)
		if !s.ForcedConnection() {
			t.Error("ForcedConnection() should be true")
		}
	})

	t.Run("Organization", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		const orgName = "My Org"
		u := "https://example.com"
		s.SetOrganizationName(orgName)
		s.SetOrganizationURL(u)
		if s.OrganizationName() != orgName {
			t.Errorf("OrganizationName() = %q, want %q", s.OrganizationName(), orgName)
		}
		if s.OrganizationURL() != u {
			t.Errorf("OrganizationURL() = %q, want %q", s.OrganizationURL(), u)
		}
	})

	t.Run("VideoService", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		val := "https://jitsi.example.com"
		s.SetVideoService(val)
		if s.VideoService() != val {
			t.Errorf("VideoService() = %q, want %q", s.VideoService(), val)
		}
	})

	t.Run("DataConversion", func(t *testing.T) {
		t.Parallel()
		_, s := setup()
		const orgName = "My Org"
		s.SetOrganizationName(orgName) // Set the value we expect
		data := s.ToData()
		if data.OrganizationName != orgName {
			t.Errorf("ToData() name = %q, want %q", data.OrganizationName, orgName)
		}

		s2 := &Settings{}
		s2.FromData(data)
		if s2.OrganizationName() != orgName {
			t.Errorf("FromData() name = %q, want %q", s2.OrganizationName(), orgName)
		}
	})

	t.Run("Save", func(t *testing.T) {
		t.Parallel()
		backend, s := setup()
		const orgName = "My Org"
		s.SetOrganizationName(orgName) // Set the value we expect to save
		if err := s.Save(); err != nil {
			t.Fatalf("Save() error: %v", err)
		}

		saved, _ := backend.LoadSettings()
		if saved.OrganizationName != orgName {
			t.Errorf("Backend name = %q, want %q", saved.OrganizationName, orgName)
		}
	})
}
