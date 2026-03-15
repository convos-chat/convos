package api

import (
	"strconv"

	"github.com/convos-chat/convos/pkg/core"
)

// ToUserSummary converts a core.User to an api.User (summary version).
func ToUserSummary(u *core.User) User {
	registered := u.Registered()
	keywords := u.HighlightKeywords()
	uid := strconv.Itoa(u.UID())
	roles := u.Roles()

	return User{
		Email:             u.Email(),
		Unread:            u.Unread(),
		Registered:        &registered,
		HighlightKeywords: &keywords,
		Uid:               &uid,
		Roles:             &roles,
	}
}

// ToUser converts a core.User to an api.User, optionally including connections and conversations.
func ToUser(u *core.User, includeConns, includeConvs bool) User {
	res := ToUserSummary(u)

	s := u.Core.Settings
	defaultConn := s.DefaultConnection()
	forcedConn := s.ForcedConnection()
	videoService := s.VideoService()

	res.DefaultConnection = &defaultConn
	res.ForcedConnection = &forcedConn
	res.VideoService = &videoService

	roles := u.Roles()
	res.Roles = &roles
	remoteAddr := u.RemoteAddress()
	res.RemoteAddress = &remoteAddr

	if includeConns {
		coreConns := u.Connections()
		conns := make([]Connection, 0, len(coreConns))
		var convs []Conversation
		if includeConvs {
			convs = make([]Conversation, 0, len(coreConns)*4)
		}

		for _, conn := range coreConns {
			apiConn := ToConnection(conn)
			conns = append(conns, apiConn)
			if includeConvs {
				for _, conv := range conn.Conversations() {
					convs = append(convs, ToConversation(conv))
				}
			}
		}
		res.Connections = &conns
		if includeConvs {
			res.Conversations = &convs
		}
	}

	return res
}

// ToConnection converts a core.Connection to an api.Connection.
func ToConnection(c core.Connection) Connection {
	name := c.Name()
	state := c.State()
	wantedState := c.WantedState()
	cmds := c.OnConnectCommands()
	urlStr := ""
	if u := c.URL(); u != nil {
		// Strip password from URL for API response
		clean := *u
		clean.User = nil
		urlStr = clean.String()
	}

	info := core.InfoMap(c.Info())
	if _, ok := info["nick"]; !ok {
		info["nick"] = c.Nick()
	}

	return Connection{
		ConnectionId:      c.ID(),
		Name:              &name,
		Url:               urlStr,
		State:             &state,
		WantedState:       &wantedState,
		OnConnectCommands: &cmds,
		Info:              &info,
	}
}

// ToConversation converts a core.Conversation to an api.Conversation.
func ToConversation(c *core.Conversation) Conversation {
	topic := c.Topic()
	frozen := c.Frozen()
	notifications := c.Notifications()
	info := core.InfoMap(c.Info())
	return Conversation{
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

// ErrResponse builds an Error response with a single message.
func ErrResponse(message string) Error {
	path := "/"
	return Error{
		Errors: &[]struct {
			Message string  `json:"message"`
			Path    *string `json:"path,omitempty"`
		}{
			{Message: message, Path: &path},
		},
	}
}
