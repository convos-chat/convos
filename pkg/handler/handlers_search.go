package handler

import (
	"context"

	"github.com/convos-chat/convos/pkg/api"
)

// SearchMessages implements api.StrictServerInterface.
func (h *Handler) SearchMessages(ctx context.Context, request api.SearchMessagesRequestObject) (api.SearchMessagesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	query := paramsToMessageQuery(request.Params.After, nil, request.Params.Before, request.Params.Limit, request.Params.Match)
	result, err := h.Core.Backend().SearchMessages(user, query)
	if err != nil {
		return nil, err
	}

	msgs := make([]api.Message, len(result.Messages))
	for i, m := range result.Messages {
		msgs[i] = coreMessageToAPI(m)
	}

	return api.SearchMessages200JSONResponse{End: &result.End, Messages: &msgs}, nil
}
