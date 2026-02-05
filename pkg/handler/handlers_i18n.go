package handler

import (
	"context"

	"github.com/convos-chat/convos/pkg/api"
)

// GetDictionary implements api.StrictServerInterface.
// Returns translation dictionary for the requested language.
// FIXME: Implement actual internationalization support.
func (h *Handler) GetDictionary(ctx context.Context, request api.GetDictionaryRequestObject) (api.GetDictionaryResponseObject, error) {
	return api.GetDictionary200JSONResponse{
		Dictionary: map[string]any{},
	}, nil
}
