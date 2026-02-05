package handler

import (
	"context"

	"github.com/convos-chat/convos/pkg/api"
)

// Embed implements api.StrictServerInterface.
// Fetches URL metadata (Open Graph, content-type) for link previews in chat.
func (h *Handler) Embed(ctx context.Context, request api.EmbedRequestObject) (api.EmbedResponseObject, error) {
	r, _ := h.getRequest(ctx)
	w, _ := h.getResponseWriter(ctx)

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
