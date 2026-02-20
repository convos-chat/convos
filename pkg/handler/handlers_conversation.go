package handler

import (
	"context"
	"errors"
	"os"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
)

// ListConversations implements api.StrictServerInterface.
func (h *Handler) ListConversations(ctx context.Context, request api.ListConversationsRequestObject) (api.ListConversationsResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	var convs []api.Conversation
	for _, conn := range user.Connections() {
		for _, conv := range conn.Conversations() {
			convs = append(convs, toAPIConversation(conv))
		}
	}
	if convs == nil {
		convs = []api.Conversation{}
	}

	return api.ListConversations200JSONResponse{Conversations: &convs}, nil
}

// ConversationMessages implements api.StrictServerInterface.
func (h *Handler) ConversationMessages(ctx context.Context, request api.ConversationMessagesRequestObject) (api.ConversationMessagesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	conn := user.GetConnection(request.ConnectionId)
	if conn == nil {
		return api.ConversationMessages404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(ErrResponse("Connection not found.")),
		}, nil
	}

	conv := conn.GetConversation(request.ConversationId)
	if conv == nil {
		return api.ConversationMessages404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(ErrResponse("Conversation not found.")),
		}, nil
	}

	query := paramsToMessageQuery(request.Params.After, request.Params.Around, request.Params.Before, request.Params.Limit, request.Params.Match)
	result, err := h.Core.Backend().LoadMessages(conv, query)
	if err != nil {
		return buildMessagesResponse(core.MessageResult{End: true}, query), nil //nolint:nilerr // return empty on backend error
	}

	return buildMessagesResponse(result, query), nil
}

// MarkConversationAsRead implements api.StrictServerInterface.
func (h *Handler) MarkConversationAsRead(ctx context.Context, request api.MarkConversationAsReadRequestObject) (api.MarkConversationAsReadResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	conn := user.GetConnection(request.ConnectionId)
	if conn == nil {
		return api.MarkConversationAsRead404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(ErrResponse("Connection not found")),
		}, nil
	}

	conv := conn.GetConversation(request.ConversationId)
	if conv != nil {
		conv.SetUnread(0)
		conv.SetNotifications(0)
	}

	return api.MarkConversationAsRead200JSONResponse{}, nil
}

// ConnectionMessages implements api.StrictServerInterface.
func (h *Handler) ConnectionMessages(ctx context.Context, request api.ConnectionMessagesRequestObject) (api.ConnectionMessagesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	conn := user.GetConnection(request.ConnectionId)
	if conn == nil {
		return api.ConnectionMessages404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(ErrResponse("Connection not found.")),
		}, nil
	}

	// Connection messages are stored in a special "" conversation
	conv := conn.GetConversation("")
	if conv == nil {
		// No server messages yet — return empty
		return api.ConnectionMessages200JSONResponse{
			Messages: &[]api.Message{},
		}, nil
	}

	query := paramsToMessageQuery(request.Params.After, request.Params.Around, request.Params.Before, request.Params.Limit, request.Params.Match)
	result, err := h.Core.Backend().LoadMessages(conv, query)
	if err != nil {
		return api.ConnectionMessages200JSONResponse{ //nolint:nilerr // return empty on backend error
			Messages: &[]api.Message{},
		}, nil
	}

	convResp := buildMessagesResponse(result, query)
	return api.ConnectionMessages200JSONResponse(convResp), nil
}

// MarkConnectionAsRead implements api.StrictServerInterface.
func (h *Handler) MarkConnectionAsRead(ctx context.Context, request api.MarkConnectionAsReadRequestObject) (api.MarkConnectionAsReadResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	conn := user.GetConnection(request.ConnectionId)
	if conn == nil {
		return api.MarkConnectionAsRead404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(ErrResponse("Connection not found")),
		}, nil
	}

	// Mark the connection-level conversation as read
	conv := conn.GetConversation("")
	if conv != nil {
		conv.SetUnread(0)
	}

	return api.MarkConnectionAsRead200JSONResponse{}, nil
}

// NotificationMessages implements api.StrictServerInterface.
func (h *Handler) NotificationMessages(ctx context.Context, request api.NotificationMessagesRequestObject) (api.NotificationMessagesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	result, err := h.Core.Backend().LoadNotifications(user, core.MessageQuery{Limit: 40})
	if err != nil {
		return api.NotificationMessages200JSONResponse{Messages: &[]api.Notification{}}, nil //nolint:nilerr // return empty on backend error
	}

	notifs := make([]api.Notification, len(result.Notifications))
	for i, n := range result.Notifications {
		notifs[i] = api.Notification{
			ConnectionId:   &n.ConnectionID,
			ConversationId: &n.ConversationID,
			From:           n.From,
			Message:        n.Message,
			Ts:             time.Unix(n.Timestamp, 0).UTC(),
		}
	}

	return api.NotificationMessages200JSONResponse{End: &result.End, Messages: &notifs}, nil
}

// MarkNotificationsAsRead implements api.StrictServerInterface.
func (h *Handler) MarkNotificationsAsRead(ctx context.Context, request api.MarkNotificationsAsReadRequestObject) (api.MarkNotificationsAsReadResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	// Clear the notifications file by truncating it
	notifFile := h.Core.Home() + "/" + user.ID() + "/notifications.log"
	_, err = os.Stat(notifFile)
	if errors.Is(err, os.ErrNotExist) {
		return api.MarkNotificationsAsRead200JSONResponse{}, nil
	}

	if err := os.Truncate(notifFile, 0); err != nil {
		return nil, err
	}

	return api.MarkNotificationsAsRead200JSONResponse{}, nil
}

// Helpers

func toAPIConversation(c *core.Conversation) api.Conversation {
	topic := c.Topic()
	frozen := c.Frozen()
	notifications := c.Notifications()
	info := c.Info()
	return api.Conversation{
		ConnectionId:   c.Connection().ID(),
		ConversationId: c.ID(),
		Frozen:         &frozen,
		Info:           &info,
		Name:           c.Name(),
		Notifications:  &notifications,
		Topic:          &topic,
		Unread:         c.Unread(),
	}
}

func paramsToMessageQuery(after *time.Time, around *time.Time, before *time.Time, limit *int, match *string) core.MessageQuery {
	q := core.MessageQuery{}
	if after != nil {
		q.After = after.Format(time.RFC3339)
	}
	if around != nil {
		q.Around = around.Format(time.RFC3339)
	}
	if before != nil {
		q.Before = before.Format(time.RFC3339)
	}
	if limit != nil {
		q.Limit = *limit
	}
	if match != nil {
		q.Match = *match
	}
	return q
}

func coreMessageToAPI(m core.Message) api.Message {
	return api.Message{
		From:      m.From,
		Highlight: &m.Highlight,
		Message:   m.Message,
		Ts:        time.Unix(m.Timestamp, 0).UTC(),
		Type:      &m.Type,
	}
}

func buildMessagesResponse(result core.MessageResult, query core.MessageQuery) api.ConversationMessages200JSONResponse {
	msgs := make([]api.Message, len(result.Messages))
	for i, m := range result.Messages {
		msgs[i] = coreMessageToAPI(m)
	}

	resp := api.ConversationMessages200JSONResponse{Messages: &msgs, End: &result.End}

	if len(result.Messages) > 0 {
		// "before" cursor: set if there are older messages beyond the returned set
		if !result.End {
			first := time.Unix(result.Messages[0].Timestamp, 0).UTC()
			resp.Before = &first
		}

		// "after" cursor: set if there are newer messages beyond the returned set.
		// When loading with "around", we're typically at the latest point, so don't
		// set "after". When loading with explicit "before" param, there are newer
		// messages the user hasn't scrolled to yet.
		if query.Before != "" && query.Around == "" {
			last := time.Unix(result.Messages[len(result.Messages)-1].Timestamp, 0).UTC()
			resp.After = &last
		}
	}

	return resp
}
