package handler

import (
	"context"
	"mime"
	"net/url"
	"path/filepath"
	"strings"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/embed"
)

// Embed implements api.StrictServerInterface.
// Fetches URL metadata (Open Graph, content-type) for link previews in chat.
func (h *Handler) Embed(ctx context.Context, request api.EmbedRequestObject) (api.EmbedResponseObject, error) {
	r, _ := h.getRequest(ctx)
	w, _ := h.getResponseWriter(ctx)

	// Handle local file URLs directly to avoid self-referential HTTP requests.
	if link := h.embedLocalFile(request.Params.Url); link != nil {
		if w != nil {
			w.Header().Set("Cache-Control", "max-age=600")
		}
		return api.Embed200JSONResponse(link.ToMap()), nil
	}

	var userAgent string
	if r != nil {
		userAgent = r.Header.Get("User-Agent")
	}

	link, err := h.Embed_.Fetch(ctx, request.Params.Url, userAgent)
	if err != nil {
		return api.Embed200JSONResponse{"errors": []map[string]string{{"message": err.Error()}}}, nil //nolint:nilerr // error communicated in response body
	}

	if w != nil {
		w.Header().Set("Cache-Control", "max-age=600")
	}

	return api.Embed200JSONResponse(link.ToMap()), nil
}

// embedLocalFile checks if the URL points to a file on this server and returns
// embed metadata directly from the backend, avoiding a self-referential HTTP request.
func (h *Handler) embedLocalFile(rawURL string) *embed.Link {
	baseURL := h.Core.Settings().BaseURL()
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return nil
	}

	// Check if this URL points to our own server
	if parsed.Host != baseURL.Host {
		return nil
	}

	// Match /api/files/{uid}/{fid} path
	prefix := "/api/files/"
	path := parsed.Path
	if !strings.HasPrefix(path, prefix) {
		return nil
	}
	rest := path[len(prefix):]
	parts := strings.SplitN(rest, "/", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return nil
	}
	uid, fid := parts[0], parts[1]

	user := h.Core.GetUser(uid)
	if user == nil {
		return nil
	}

	_, filename, err := h.Core.Backend().GetFile(user, fid)
	if err != nil {
		return nil
	}

	ct := mime.TypeByExtension(filepath.Ext(filename))
	link := &embed.Link{URL: rawURL, Title: filename}

	switch {
	case strings.HasPrefix(ct, "image/"):
		link.Type = "photo"
		link.HTML = embed.RenderPhoto(link)
	case strings.HasPrefix(ct, "video/"):
		link.Type = "video"
		link.HTML = embed.RenderVideo(link, ct)
	default:
		link.Type = "link"
	}

	return link
}
