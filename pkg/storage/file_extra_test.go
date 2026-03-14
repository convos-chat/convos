package storage

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
)

func TestFileBackend_Settings(t *testing.T) {
	t.Parallel()
	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)

	data := core.SettingsData{
		OrganizationName: "My Org",
		OpenToPublic:     true,
	}

	t.Run("SaveAndLoad", func(t *testing.T) {
		t.Parallel()
		if err := b.SaveSettings(data); err != nil {
			t.Fatalf("SaveSettings() error: %v", err)
		}

		loaded, err := b.LoadSettings()
		if err != nil {
			t.Fatalf("LoadSettings() error: %v", err)
		}

		if loaded.OrganizationName != data.OrganizationName {
			t.Errorf("Expected name %q, got %q", data.OrganizationName, loaded.OrganizationName)
		}
		if loaded.OpenToPublic != data.OpenToPublic {
			t.Error("Expected OpenToPublic to be true")
		}
	})
}

func TestFileBackend_Profiles(t *testing.T) {
	t.Parallel()
	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)

	profile := core.ConnectionProfileData{
		ID:  "irc-libera",
		URL: "irc://irc.libera.chat",
	}

	t.Run("SaveAndLoad", func(t *testing.T) {
		t.Parallel()
		if err := b.SaveConnectionProfile(profile); err != nil {
			t.Fatalf("SaveConnectionProfile() error: %v", err)
		}

		// Perl-compatible path: settings/connections/id.json (not profiles/id.json)
		wantPath := filepath.Join(tmpDir, "settings", "connections", profile.ID+".json")
		if _, err := os.Stat(wantPath); os.IsNotExist(err) {
			t.Errorf("Profile not stored at correct path %s", wantPath)
		}

		profiles, err := b.LoadConnectionProfiles()
		if err != nil {
			t.Fatalf("LoadConnectionProfiles() error: %v", err)
		}

		if len(profiles) != 1 {
			t.Fatalf("Expected 1 profile, got %d", len(profiles))
		}
		if profiles[0].ID != profile.ID {
			t.Errorf("Expected ID %q, got %q", profile.ID, profiles[0].ID)
		}
	})

	t.Run("Delete", func(t *testing.T) {
		t.Parallel()
		if err := b.DeleteConnectionProfile(profile.ID); err != nil {
			t.Fatalf("DeleteConnectionProfile() error: %v", err)
		}

		profiles, _ := b.LoadConnectionProfiles()
		if len(profiles) != 0 {
			t.Error("Profile should have been deleted")
		}
	})
}

func TestFileBackend_Files(t *testing.T) { //nolint:tparallel // subtests share state and must run sequentially
	t.Parallel()
	tmpDir := t.TempDir()
	b := NewFileBackend(tmpDir)
	c := core.New(core.WithBackend(b))
	user, _ := c.User("test@example.com")

	content := []byte("hello world")
	name := "test.txt"

	t.Run("SaveAndLoad", func(t *testing.T) { //nolint:paralleltest // subtests share state and must run sequentially
		f, err := b.SaveFile(user, name, content)
		if err != nil {
			t.Fatalf("SaveFile() error: %v", err)
		}

		// Perl-compatible: upload stored as id.json (metadata) + id.data (content)
		uploadDir := filepath.Join(tmpDir, "test@example.com", "upload")
		metaPath := filepath.Join(uploadDir, f.ID+".json")
		dataPath := filepath.Join(uploadDir, f.ID+".data")

		if _, err := os.Stat(metaPath); os.IsNotExist(err) {
			t.Errorf("Upload metadata file not found at %s", metaPath)
		}
		if _, err := os.Stat(dataPath); os.IsNotExist(err) {
			t.Errorf("Upload data file not found at %s", dataPath)
		}

		// Verify metadata JSON contains original filename
		if _, err := os.Stat(metaPath); err == nil {
			raw, _ := os.ReadFile(metaPath)
			var meta map[string]any
			if err := json.Unmarshal(raw, &meta); err != nil {
				t.Fatalf("metadata JSON parse error: %v", err)
			}
			if meta["filename"] != name {
				t.Errorf("metadata filename = %v, want %q", meta["filename"], name)
			}
		}

		files, _ := b.LoadFiles(user)
		if len(files) != 1 {
			t.Fatalf("Expected 1 file, got %d", len(files))
		}
		// LoadFiles should return the original filename, not the ID
		if files[0].Name != name {
			t.Errorf("LoadFiles().Name = %q, want %q", files[0].Name, name)
		}

		gotContent, gotName, err := b.GetFile(user, f.ID)
		if err != nil {
			t.Fatalf("GetFile() error: %v", err)
		}
		if gotName != name {
			t.Errorf("Expected name %q, got %q", name, gotName)
		}
		if !bytes.Equal(gotContent, content) {
			t.Errorf("Expected content %q, got %q", string(content), string(gotContent))
		}
	})

	t.Run("Delete", func(t *testing.T) { //nolint:paralleltest // subtests share state and must run sequentially
		files, _ := b.LoadFiles(user)
		fid := files[0].ID
		if err := b.DeleteFile(user, fid); err != nil {
			t.Fatalf("DeleteFile() error: %v", err)
		}

		filesAfter, _ := b.LoadFiles(user)
		if len(filesAfter) != 0 {
			t.Error("File should have been deleted")
		}
	})
}
