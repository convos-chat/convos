package i18n

import (
	"embed"
	"io"
	"io/fs"
	"path/filepath"
	"strings"
	"sync"

	"github.com/leonelquinteros/gotext"
)

//go:embed assets/*.po
var assetsFS embed.FS

type LangMeta struct {
	LanguageTeam string `json:"language_team"`
}

type Catalog struct {
	pos  map[string]*gotext.Po
	meta map[string]LangMeta
	mu   sync.RWMutex
}

// NewCatalog loads *.po files from the embedded assets.
func NewCatalog() (*Catalog, error) {
	fsys, err := fs.Sub(assetsFS, "assets")
	if err != nil {
		return nil, err
	}
	return NewCatalogFromFS(fsys)
}

// NewCatalogFromFS loads *.po files from the provided fsys.
func NewCatalogFromFS(fsys fs.FS) (*Catalog, error) {
	c := &Catalog{
		pos:  make(map[string]*gotext.Po),
		meta: make(map[string]LangMeta),
	}

	err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if filepath.Ext(path) != ".po" {
			return nil
		}

		f, err := fsys.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()

		data, err := io.ReadAll(f)
		if err != nil {
			return err
		}

		po := gotext.NewPo()
		po.Parse(data)

		// Extract language code from filename (e.g., "en.po" -> "en")
		lang := strings.TrimSuffix(filepath.Base(path), ".po")
		c.pos[lang] = po

		// Extract Language-Team header
		team := po.GetDomain().Headers.Get("Language-Team")
		c.meta[lang] = LangMeta{LanguageTeam: team}

		return nil
	})

	if err != nil {
		return nil, err
	}

	return c, nil
}

// Dictionary returns the translation map for the given language.
// It falls back to "en" if the requested language is not available.
func (c *Catalog) Dictionary(lang string) map[string]string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	po, ok := c.pos[lang]
	if !ok {
		// Fallback to English
		po, ok = c.pos["en"]
		if !ok {
			return map[string]string{}
		}
	}

	domain := po.GetDomain()
	if domain == nil {
		return map[string]string{}
	}

	translations := domain.GetTranslations()
	result := make(map[string]string, len(translations))

	for msgid, t := range translations {
		if t.IsTranslated() {
			result[msgid] = t.Get()
		}
	}

	return result
}

// AvailableLanguages returns the metadata for all available languages.
func (c *Catalog) AvailableLanguages() map[string]LangMeta {
	c.mu.RLock()
	defer c.mu.RUnlock()

	// Return a copy to be safe
	result := make(map[string]LangMeta, len(c.meta))
	for k, v := range c.meta {
		result[k] = v
	}
	return result
}
