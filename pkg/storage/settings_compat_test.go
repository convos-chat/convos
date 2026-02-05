package storage

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
)

func TestPerlSettingsCompatibility(t *testing.T) {
	t.Parallel()
	tmpHome, err := os.MkdirTemp("", "convos-settings-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpHome)

	//nolint:gosec // test fixture, not real credentials
	perlSettings := `{"base_url":"http:\/\/localhost:3000\/","contact":"mailto:root@localhost","default_connection":"irc:\/\/irc.libera.chat:6697\/%23convos","forced_connection":false,"local_secret":"b28f14b5032323637a82617d2d80e463f4106021","open_to_public":false,"organization_name":"Convos","organization_url":"https:\/\/convos.chat","session_secrets":["38c32ad40dfc198200e979f43c4c5ed42eed045d"],"video_service":"https:\/\/test.jit.si\/"}`

	err = os.WriteFile(filepath.Join(tmpHome, "settings.json"), []byte(perlSettings), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	backend := NewFileBackend(tmpHome)
	data, err := backend.LoadSettings()
	if err != nil {
		t.Fatalf("LoadSettings failed: %v", err)
	}

	if data.BaseURL != "http://localhost:3000/" {
		t.Errorf("Expected BaseURL http://localhost:3000/, got %s", data.BaseURL)
	}
	if data.VideoService != "https://test.jit.si/" {
		t.Errorf("Expected VideoService https://test.jit.si/, got %s", data.VideoService)
	}
	if len(data.SessionSecrets) != 1 || data.SessionSecrets[0] != "38c32ad40dfc198200e979f43c4c5ed42eed045d" {
		t.Errorf("SessionSecrets mismatch: %v", data.SessionSecrets)
	}
	if data.LocalSecret != "b28f14b5032323637a82617d2d80e463f4106021" {
		t.Errorf("LocalSecret mismatch: %s", data.LocalSecret)
	}

	// Verify Roundtrip
	savedJSON, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}

	var data2 core.SettingsData
	err = json.Unmarshal(savedJSON, &data2)
	if err != nil {
		t.Fatal(err)
	}

	if data2.VideoService != data.VideoService {
		t.Errorf("Roundtrip failed for VideoService")
	}
}
