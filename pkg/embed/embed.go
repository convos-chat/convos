// Package embed provides functionality to fetch and parse metadata from URLs for link previews.
package embed

import (
	"bytes"
	"context"
	"embed"
	"errors"
	"fmt"
	"html/template"
	"io"
	"mime"
	"net"
	"net/http"
	"net/url"
	"path"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

//go:embed templates/*.html
var embeddedTemplates embed.FS

// HTML templates matching LinkEmbedder output format.
var (
	photoTmpl         = template.Must(template.New("photo").ParseFS(embeddedTemplates, "templates/photo.html")).Lookup("photo.html")
	videoTmpl         = template.Must(template.New("video").ParseFS(embeddedTemplates, "templates/video.html")).Lookup("video.html")
	richCardImageTmpl = template.Must(template.New("richCardImage").ParseFS(embeddedTemplates, "templates/rich_card_image.html")).Lookup("rich_card_image.html")
	richCardTmpl      = template.Must(template.New("richCard").ParseFS(embeddedTemplates, "templates/rich_card.html")).Lookup("rich_card.html")
)

// ErrHTTPStatus is returned when the fetched URL responds with an error status code.
var ErrHTTPStatus = errors.New("unexpected HTTP status")

// Link holds metadata extracted from a URL, matching the LinkEmbedder JSON format.
type Link struct {
	AuthorName   string `json:"author_name,omitempty"`
	AuthorURL    string `json:"author_url,omitempty"`
	CacheAge     int    `json:"cache_age,omitempty"`
	Description  string `json:"description,omitempty"`
	Height       int    `json:"height,omitempty"`
	HTML         string `json:"html,omitempty"`
	ProviderName string `json:"provider_name,omitempty"`
	ProviderURL  string `json:"provider_url,omitempty"`
	ThumbnailURL string `json:"thumbnail_url,omitempty"`
	Title        string `json:"title,omitempty"`
	Type         string `json:"type"`
	URL          string `json:"url"`
	Width        int    `json:"width,omitempty"`
}

// ToMap converts a Link to a map for the API response.
func (l *Link) ToMap() map[string]any {
	m := map[string]any{
		"type": l.Type,
		"url":  l.URL,
	}
	if l.AuthorName != "" {
		m["author_name"] = l.AuthorName
	}
	if l.AuthorURL != "" {
		m["author_url"] = l.AuthorURL
	}
	if l.CacheAge != 0 {
		m["cache_age"] = l.CacheAge
	}
	if l.Description != "" {
		m["description"] = l.Description
	}
	if l.Height != 0 {
		m["height"] = l.Height
	}
	if l.HTML != "" {
		m["html"] = l.HTML
	}
	if l.ProviderName != "" {
		m["provider_name"] = l.ProviderName
	}
	if l.ProviderURL != "" {
		m["provider_url"] = l.ProviderURL
	}
	if l.ThumbnailURL != "" {
		m["thumbnail_url"] = l.ThumbnailURL
	}
	if l.Title != "" {
		m["title"] = l.Title
	}
	if l.Width != 0 {
		m["width"] = l.Width
	}
	return m
}

type cacheEntry struct {
	link      *Link
	fetchedAt time.Time
}

// Client fetches and caches URL metadata for link previews.
type Client struct {
	HTTPClient *http.Client
	MaxEntries int
	TTL        time.Duration

	mu    sync.Mutex
	cache map[string]cacheEntry
	order []string // insertion order for eviction
}

// NewClient creates an embed Client with sensible defaults.
func NewClient() *Client {
	return &Client{
		HTTPClient: &http.Client{Timeout: 5 * time.Second},
		MaxEntries: 100,
		TTL:        10 * time.Minute,
		cache:      make(map[string]cacheEntry),
	}
}

// Fetch retrieves metadata for the given URL. Results are cached.
func (c *Client) Fetch(ctx context.Context, rawURL, userAgent string) (*Link, error) {
	c.mu.Lock()
	if entry, ok := c.cache[rawURL]; ok && time.Since(entry.fetchedAt) < c.TTL {
		c.mu.Unlock()
		return entry.link, nil
	}
	c.mu.Unlock()

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return nil, fmt.Errorf("invalid URL: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, err
	}
	if userAgent != "" {
		req.Header.Set("User-Agent", userAgent)
	}
	req.Header.Set("Accept", "text/html, image/*, video/*, */*")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		return nil, fmt.Errorf("%w: %d", ErrHTTPStatus, resp.StatusCode)
	}

	ct := resp.Header.Get("Content-Type")
	// Fall back to MIME type from URL extension when the server returns a
	// generic type (e.g. application/octet-stream) or no Content-Type at all.
	if ct == "" || strings.HasPrefix(ct, "application/octet-stream") {
		if extType := mime.TypeByExtension(path.Ext(parsed.Path)); extType != "" {
			ct = extType
		}
	}

	link := &Link{
		URL:          rawURL,
		ProviderName: providerName(parsed.Hostname()),
		ProviderURL:  fmt.Sprintf("%s://%s", parsed.Scheme, parsed.Host),
	}

	switch {
	case strings.HasPrefix(ct, "image/"):
		link.Type = "photo"
		link.Title = titleFromPath(parsed.Path)
		link.HTML = renderPhoto(link)
	case strings.HasPrefix(ct, "video/"):
		link.Type = "video"
		link.Title = titleFromPath(parsed.Path)
		link.HTML = renderVideo(link, ct)
	case strings.HasPrefix(ct, "text/html"), strings.HasPrefix(ct, "application/xhtml"):
		body, err := io.ReadAll(io.LimitReader(resp.Body, 512*1024)) // 512KB max
		if err != nil {
			return nil, err
		}
		parseHTMLMeta(bytes.NewReader(body), link)
		link.Type = "rich"
		if link.Title != "" {
			link.HTML = renderRichCard(link)
		}
	default:
		link.Type = "link"
	}

	c.mu.Lock()
	c.cache[rawURL] = cacheEntry{link: link, fetchedAt: time.Now()}
	c.order = append(c.order, rawURL)
	for len(c.cache) > c.MaxEntries {
		delete(c.cache, c.order[0])
		c.order = c.order[1:]
	}
	c.mu.Unlock()

	return link, nil
}

// providerName derives a display name from a hostname.
// "github.com" → "GitHub", "www.example.co.uk" → "Example"
func providerName(hostname string) string {
	if ip := net.ParseIP(hostname); ip != nil {
		return hostname
	}

	hostname = strings.TrimPrefix(hostname, "www.")
	parts := strings.Split(hostname, ".")
	if len(parts) == 0 {
		return hostname
	}
	name := parts[0]
	if name == "" {
		return hostname
	}
	return strings.ToUpper(name[:1]) + name[1:]
}

func titleFromPath(p string) string {
	base := path.Base(p)
	if base == "/" || base == "." {
		return ""
	}
	return base
}

// parseHTMLMeta extracts Open Graph, Twitter Card, and standard meta from HTML.
func parseHTMLMeta(r io.Reader, link *Link) {
	z := html.NewTokenizer(r)
	inHead := false
	var titleBuf strings.Builder
	inTitle := false

	for {
		tt := z.Next()
		switch tt {
		case html.ErrorToken:
			goto done
		case html.StartTagToken, html.SelfClosingTagToken:
			tn, hasAttr := z.TagName()
			name := atom.Lookup(tn)

			if name == atom.Head {
				inHead = true
				continue
			}
			if name == atom.Body {
				goto done // stop once we hit <body>
			}
			if name == atom.Title && inHead {
				inTitle = true
				continue
			}

			if name == atom.Meta && hasAttr && inHead {
				attrs := tokenAttrs(z)
				handleMeta(attrs, link)
			}
		case html.EndTagToken:
			tn, _ := z.TagName()
			name := atom.Lookup(tn)
			if name == atom.Head {
				goto done
			}
			if name == atom.Title {
				inTitle = false
			}
		case html.TextToken:
			if inTitle {
				titleBuf.Write(z.Text())
			}
		}
	}

done:
	// <title> is the lowest-priority fallback
	if link.Title == "" {
		link.Title = strings.TrimSpace(titleBuf.String())
	}
}

func tokenAttrs(z *html.Tokenizer) map[string]string {
	attrs := make(map[string]string)
	for {
		key, val, more := z.TagAttr()
		k := string(key)
		if k != "" {
			attrs[k] = string(val)
		}
		if !more {
			break
		}
	}
	return attrs
}

func handleMeta(attrs map[string]string, link *Link) {
	prop := attrs["property"]
	name := attrs["name"]
	content := attrs["content"]
	if content == "" {
		return
	}

	switch prop {
	case "og:title":
		link.Title = content
	case "og:description":
		if link.Description == "" {
			link.Description = content
		}
	case "og:image", "og:image:url":
		if link.ThumbnailURL == "" {
			link.ThumbnailURL = content
		}
	case "og:url":
		// keep original URL for display, don't override
	}

	switch name {
	case "twitter:title":
		if link.Title == "" {
			link.Title = content
		}
	case "twitter:description":
		if link.Description == "" {
			link.Description = content
		}
	case "twitter:image":
		if link.ThumbnailURL == "" {
			link.ThumbnailURL = content
		}
	case "description":
		if link.Description == "" {
			link.Description = content
		}
	case "author":
		if link.AuthorName == "" {
			link.AuthorName = content
		}
	}
}

func execTemplate(t *template.Template, data any) string {
	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return ""
	}
	return buf.String()
}

func renderPhoto(l *Link) string {
	return execTemplate(photoTmpl, map[string]string{
		"Provider": strings.ToLower(l.ProviderName),
		"Src":      l.URL,
		"Alt":      l.Title,
	})
}

func renderVideo(l *Link, mimeType string) string {
	// extract just the media type (strip params like charset)
	if idx := strings.Index(mimeType, ";"); idx >= 0 {
		mimeType = strings.TrimSpace(mimeType[:idx])
	}
	return execTemplate(videoTmpl, map[string]string{
		"Provider": strings.ToLower(l.ProviderName),
		"Src":      l.URL,
		"Mime":     mimeType,
	})
}

func renderRichCard(l *Link) string {
	data := map[string]string{
		"Provider":    strings.ToLower(l.ProviderName),
		"URL":         l.URL,
		"Title":       l.Title,
		"Description": l.Description,
		"AuthorName":  l.AuthorName,
		"AuthorURL":   l.AuthorURL,
	}

	if l.ThumbnailURL != "" {
		data["Thumbnail"] = l.ThumbnailURL
		data["Alt"] = l.AuthorName
		return execTemplate(richCardImageTmpl, data)
	}
	return execTemplate(richCardTmpl, data)
}
