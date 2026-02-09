package i18n

import (
	"strings"
	"testing"
	"testing/fstest"
)

func TestNewCatalog(t *testing.T) {
	t.Parallel()
	fsys := fstest.MapFS{
		"en.po": {Data: []byte(`
msgid ""
msgstr ""
"Language-Team: English \n"

msgid "hello"
msgstr "Hello"
`)},
		"es.po": {Data: []byte(`
msgid ""
msgstr ""
"Language-Team: Spanish \n"

msgid "hello"
msgstr "Hola"
`)},
		"ignored.txt": {Data: []byte("should be ignored")},
	}

	c, err := NewCatalogFromFS(fsys)
	if err != nil {
		t.Fatalf("NewCatalog failed: %v", err)
	}

	// Test AvailableLanguages
	langs := c.AvailableLanguages()
	if len(langs) != 2 {
		t.Errorf("expected 2 languages, got %d", len(langs))
	}
	if !strings.Contains(langs["en"].LanguageTeam, "English") {
		t.Errorf("expected English team, got %q", langs["en"].LanguageTeam)
	}

	// Test Dictionary
	dictEn := c.Dictionary("en")
	if dictEn["hello"] != "Hello" {
		t.Errorf("expected Hello, got %q", dictEn["hello"])
	}

	dictEs := c.Dictionary("es")
	if dictEs["hello"] != "Hola" {
		t.Errorf("expected Hola, got %q", dictEs["hello"])
	}

	// Test Fallback
	dictFr := c.Dictionary("fr") // Should fall back to en
	if dictFr["hello"] != "Hello" {
		t.Errorf("expected fallback to Hello, got %q", dictFr["hello"])
	}
}
