package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/convos-chat/convos/pkg/api"
)

type dictionaryResponse struct {
	AvailableLanguages map[string]any `json:"available_languages"`
	Dictionary         map[string]any `json:"dictionary"`
}

func (r dictionaryResponse) VisitGetDictionaryResponse(w http.ResponseWriter) error {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "max-age=86400")
	w.WriteHeader(200)
	return json.NewEncoder(w).Encode(r)
}

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
	metaAny := make(map[string]any, len(meta))
	for k, v := range meta {
		metaAny[k] = v
	}

	// FIXME: Update the contract so we can use proper response here
	return dictionaryResponse{
		Dictionary:         dictAny,
		AvailableLanguages: metaAny,
	}, nil
}
