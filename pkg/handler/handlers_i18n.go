package handler

import (
	"context"

	"github.com/convos-chat/convos/pkg/api"
)

// GetDictionary implements api.StrictServerInterface.
// Returns translation dictionary for the requested language.
func (h *Handler) GetDictionary(ctx context.Context, request api.GetDictionaryRequestObject) (api.GetDictionaryResponseObject, error) {
	lang := request.Lang

	dict := h.I18n.Dictionary(lang)
	dictAny := make(map[string]any, len(dict))
	for k, v := range dict {
		dictAny[k] = v
	}

	meta := h.I18n.AvailableLanguages()
	avail := make(map[string]struct {
		LanguageTeam *string `json:"language_team,omitempty"`
	}, len(meta))

	for k, v := range meta {
		team := v.LanguageTeam
		avail[k] = struct {
			LanguageTeam *string `json:"language_team,omitempty"`
		}{
			LanguageTeam: &team,
		}
	}

	return api.GetDictionary200JSONResponse{
		Dictionary:         dictAny,
		AvailableLanguages: &avail,
	}, nil
}
