package server

import (
	"io/fs"
	"testing"
	"testing/fstest"
)

func TestOverlayFS(t *testing.T) {
	t.Parallel()

	lower := fstest.MapFS{
		"themes/builtin.css": {Data: []byte("/* builtin */")},
		"themes/shared.css":  {Data: []byte("/* lower shared */")},
		"images/logo.png":    {Data: []byte("lower-logo")},
		"favicon.ico":        {Data: []byte("lower-favicon")},
	}

	upper := fstest.MapFS{
		"themes/custom.css": {Data: []byte("/* custom theme */")},
		"themes/shared.css": {Data: []byte("/* upper shared */")},
	}

	ofs := &overlayFS{upper: upper, lower: lower}

	t.Run("Open_UpperTakesPrecedence", func(t *testing.T) {
		t.Parallel()
		data, err := fs.ReadFile(ofs, "themes/shared.css")
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "/* upper shared */" {
			t.Errorf("expected upper content, got %q", string(data))
		}
	})

	t.Run("Open_FallsBackToLower", func(t *testing.T) {
		t.Parallel()
		data, err := fs.ReadFile(ofs, "themes/builtin.css")
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "/* builtin */" {
			t.Errorf("expected lower content, got %q", string(data))
		}
	})

	t.Run("Open_NotFound", func(t *testing.T) {
		t.Parallel()
		_, err := ofs.Open("nonexistent.txt")
		if err == nil {
			t.Fatal("expected error for nonexistent file")
		}
	})

	t.Run("ReadFile", func(t *testing.T) {
		t.Parallel()
		data, err := ofs.ReadFile("favicon.ico")
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != "lower-favicon" {
			t.Errorf("expected lower-favicon, got %q", string(data))
		}
	})

	t.Run("Stat_Upper", func(t *testing.T) {
		t.Parallel()
		info, err := ofs.Stat("themes/custom.css")
		if err != nil {
			t.Fatal(err)
		}
		if info.Name() != "custom.css" {
			t.Errorf("expected custom.css, got %q", info.Name())
		}
	})

	t.Run("Stat_Lower", func(t *testing.T) {
		t.Parallel()
		info, err := ofs.Stat("images/logo.png")
		if err != nil {
			t.Fatal(err)
		}
		if info.Name() != "logo.png" {
			t.Errorf("expected logo.png, got %q", info.Name())
		}
	})

	t.Run("ReadDir_MergesEntries", func(t *testing.T) {
		t.Parallel()
		entries, err := ofs.ReadDir("themes")
		if err != nil {
			t.Fatal(err)
		}

		names := make([]string, len(entries))
		for i, e := range entries {
			names[i] = e.Name()
		}

		// Should have 3 unique entries: builtin.css, custom.css, shared.css (sorted)
		expected := []string{"builtin.css", "custom.css", "shared.css"}
		if len(names) != len(expected) {
			t.Fatalf("expected %d entries, got %d: %v", len(expected), len(names), names)
		}
		for i, name := range expected {
			if names[i] != name {
				t.Errorf("entry %d: expected %q, got %q", i, name, names[i])
			}
		}
	})

	t.Run("ReadDir_UpperOnly", func(t *testing.T) {
		t.Parallel()
		// "images" only exists in lower
		entries, err := ofs.ReadDir("images")
		if err != nil {
			t.Fatal(err)
		}
		if len(entries) != 1 || entries[0].Name() != "logo.png" {
			t.Errorf("unexpected entries: %v", entries)
		}
	})

	t.Run("ReadDir_NotFound", func(t *testing.T) {
		t.Parallel()
		_, err := ofs.ReadDir("nonexistent")
		if err == nil {
			t.Fatal("expected error for nonexistent directory")
		}
	})
}
