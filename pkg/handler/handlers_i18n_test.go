package handler

import (
	"context"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
)

func TestGetDictionary(t *testing.T) {
	t.Parallel()
	h := NewHandler(nil, nil, nil)
	resp, _ := h.GetDictionary(context.Background(), api.GetDictionaryRequestObject{
		Lang: "en",
	})

	if r, ok := resp.(api.GetDictionary200JSONResponse); ok {
		// FIXME: This is a placeholder test. We should verify that the dictionary contains expected keys and values once actual i18n support is implemented.
		if len(r.Dictionary) != 0 {
			t.Error("Expected empty dictionary")
		}
	} else {
		t.Errorf("Unexpected response type: %T", resp)
	}
}
