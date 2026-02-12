package handler

import (
	"context"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/convos-chat/convos/pkg/api"
)

// GetVapidKey handles GET /push/vapid
func (h *Handler) GetVapidKey(ctx context.Context, request api.GetVapidKeyRequestObject) (api.GetVapidKeyResponseObject, error) {
	pub, _, err := h.Core.Settings().VAPIDKeys()
	if err != nil {
		return api.GetVapidKey500JSONResponse{
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(ErrResponse(err.Error())),
		}, nil
	}

	return api.GetVapidKey200JSONResponse{
		PublicKey: pub,
	}, nil
}

// SubscribeToPush handles POST /push/subscribe
func (h *Handler) SubscribeToPush(ctx context.Context, request api.SubscribeToPushRequestObject) (api.SubscribeToPushResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return api.SubscribeToPush401JSONResponse{
			UnauthorizedJSONResponse: api.UnauthorizedJSONResponse(ErrResponse("Unauthorized")),
		}, nil
	}

	body := request.Body
	if body == nil {
		return api.SubscribeToPush400JSONResponse{
			BadRequestJSONResponse: api.BadRequestJSONResponse(ErrResponse("Missing body")),
		}, nil
	}

	endpoint := body.Endpoint
	auth := body.Keys.Auth
	p256dh := body.Keys.P256dh

	if endpoint == "" || auth == "" || p256dh == "" {
		return api.SubscribeToPush400JSONResponse{
			BadRequestJSONResponse: api.BadRequestJSONResponse(ErrResponse("Invalid subscription data")),
		}, nil
	}

	sub := webpush.Subscription{
		Endpoint: endpoint,
		Keys: webpush.Keys{
			Auth:   auth,
			P256dh: p256dh,
		},
	}

	user.AddSubscription(sub)
	if err := user.Save(); err != nil {
		return api.SubscribeToPush500JSONResponse{
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(ErrResponse(err.Error())),
		}, nil
	}

	return api.SubscribeToPush200JSONResponse{
		Message: ptr("Subscribed"),
	}, nil
}

// UnsubscribeFromPush handles POST /push/unsubscribe
func (h *Handler) UnsubscribeFromPush(ctx context.Context, request api.UnsubscribeFromPushRequestObject) (api.UnsubscribeFromPushResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return api.UnsubscribeFromPush401JSONResponse{
			UnauthorizedJSONResponse: api.UnauthorizedJSONResponse(ErrResponse("Unauthorized")),
		}, nil
	}

	body := request.Body
	if body == nil || body.Endpoint == "" {
		return api.UnsubscribeFromPush400JSONResponse{
			BadRequestJSONResponse: api.BadRequestJSONResponse(ErrResponse("Missing endpoint")),
		}, nil
	}

	user.RemoveSubscription(body.Endpoint)
	if err := user.Save(); err != nil {
		return api.UnsubscribeFromPush500JSONResponse{
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(ErrResponse(err.Error())),
		}, nil
	}

	return api.UnsubscribeFromPush200JSONResponse{
		Message: ptr("Unsubscribed"),
	}, nil
}
