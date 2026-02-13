package handler

import (
	"context"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/i18n"
)

func TestGetDictionary(t *testing.T) {
	t.Parallel()
	h := NewHandler(nil, nil, nil, nil)

	// Setup test catalog
	fsys := fstest.MapFS{
		"en.po": {Data: []byte(`
msgid ""
msgstr ""
"Language-Team: English \n"

msgid "hello"
msgstr "Hello"
`)},
	}
	catalog, err := i18n.NewCatalogFromFS(fsys)
	if err != nil {
		t.Fatalf("Failed to create catalog: %v", err)
	}
	h.I18n = catalog

	resp, _ := h.GetDictionary(context.Background(), api.GetDictionaryRequestObject{
		Lang: "en",
	})

	r, ok := resp.(api.GetDictionary200JSONResponse)
	if !ok {
		t.Errorf("Unexpected response type: %T", resp)
		return
	}

	if len(r.Dictionary) == 0 {
		t.Error("Expected non-empty dictionary")
	}
	if r.Dictionary["hello"] != "Hello" {
		t.Errorf("Expected 'Hello', got %v", r.Dictionary["hello"])
	}

	if r.AvailableLanguages == nil || len(*r.AvailableLanguages) == 0 {
		t.Error("Expected available languages")
		return
	}

	meta, ok := (*r.AvailableLanguages)["en"]
	if !ok {
		t.Errorf("Expected 'en' in available languages")
		return
	}

	if meta.LanguageTeam == nil || !strings.Contains(*meta.LanguageTeam, "English") {
		t.Errorf("Expected LanguageTeam to contain 'English', got %v", meta.LanguageTeam)
	}
}
