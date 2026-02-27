package core

import (
	"encoding/json"
	"maps"
)

// MessageType represents the type of a chat message.
type MessageType string

const (
	// MessageTypePrivate is a private message (PRIVMSG in IRC).
	MessageTypePrivate MessageType = "private"

	// MessageTypeNotice is a notice message (NOTICE in IRC).
	MessageTypeNotice MessageType = "notice"

	// MessageTypeAction is a CTCP ACTION message (/me in IRC).
	MessageTypeAction MessageType = "action"

	// MessageTypeError is an error message shown to the user.
	MessageTypeError MessageType = "error"

	// MessageTypeReaction is a reaction to a message (IRCv3 draft/react).
	MessageTypeReaction MessageType = "reaction"
)

// EventType represents the type of a WebSocket event sent to the frontend.
type EventType string

const (
	// EventTypeMessage is a chat message event.
	EventTypeMessage EventType = "message"

	// EventTypeState is a state change event (connection, frozen, join, part, etc.).
	EventTypeState EventType = "state"

	// EventTypeSent is a command response event (for /list, /names, etc.).
	EventTypeSent EventType = "sent"

	// EventTypePong is a ping response event.
	EventTypePong EventType = "pong"

	// EventTypeHandshake is a connection handshake event.
	EventTypeHandshake EventType = "handshake"

	// EventTypeLoad is a user data load event.
	EventTypeLoad EventType = "load"
)

// StateEventType represents the subtype of a state event.
// State events use EventTypeState and include a "type" field
// specifying the kind of state change.
type StateEventType string

const (
	// StateEventConnection is a connection state change.
	StateEventConnection StateEventType = "connection"

	// StateEventFrozen is a conversation frozen state change.
	StateEventFrozen StateEventType = "frozen"

	// StateEventJoin is a user joining a channel.
	StateEventJoin StateEventType = "join"

	// StateEventPart is a user leaving a channel.
	StateEventPart StateEventType = "part"

	// StateEventQuit is a user quitting the server.
	StateEventQuit StateEventType = "quit"

	// StateEventKick is a user being kicked from a channel.
	StateEventKick StateEventType = "kick"

	// StateEventNickChange is a user changing their nickname.
	StateEventNickChange StateEventType = "nick_change"

	// StateEventInvite is a user being invited to a channel.
	StateEventInvite StateEventType = "invite"

	// StateEventMode is a channel or user mode change.
	StateEventMode StateEventType = "mode"

	// StateEventTopic is a channel topic change.
	StateEventTopic StateEventType = "topic"

	// StateEventTyping is a typing indicator (IRCv3 +typing).
	StateEventTyping StateEventType = "typing"

	// StateEventParticipants is a participant list update.
	StateEventParticipants StateEventType = "participants"

	// StateEventInfo is a generic info event (user modes, connection info, etc.).
	StateEventInfo StateEventType = "info"
)

// Event is the base interface implemented by all event types.
type Event interface {
	EventType() EventType
	GetConnectionID() string
	SetConnectionID(string)
	GetTS() string
	SetTS(string)
}

// BaseEvent provides common fields for all events.
// Embed this in concrete event types.
type BaseEvent struct {
	ConnectionID string `json:"connection_id,omitempty"`
	TS           string `json:"ts,omitempty"`
}

// GetConnectionID returns the connection ID.
func (b *BaseEvent) GetConnectionID() string {
	return b.ConnectionID
}

// SetConnectionID sets the connection ID.
func (b *BaseEvent) SetConnectionID(id string) {
	b.ConnectionID = id
}

// GetTS returns the timestamp.
func (b *BaseEvent) GetTS() string {
	return b.TS
}

// SetTS sets the timestamp.
func (b *BaseEvent) SetTS(ts string) {
	b.TS = ts
}

// marshalWithExtras marshals v and then merges the extras map into the
// resulting JSON object. Each concrete event type uses this to inject the
// "event" (and for state events "type") keys without storing them as struct
// fields that callers must remember to set.
func marshalWithExtras(v any, extras map[string]any) ([]byte, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	for k, v := range extras {
		if raw, merr := json.Marshal(v); merr == nil {
			m[k] = raw
		}
	}
	return json.Marshal(m)
}

// MessageEvent represents a chat message.
type MessageEvent struct {
	BaseEvent
	ConversationID string      `json:"conversation_id"`
	From           string      `json:"from"`
	Message        string      `json:"message"`
	Type           MessageType `json:"type"`
	Highlight      bool        `json:"highlight"`
	MsgID          string      `json:"msgid,omitempty"`
	Account        string      `json:"account,omitempty"`
	ReplyTo        string      `json:"reply_to,omitempty"`
}

func (MessageEvent) EventType() EventType { return EventTypeMessage }

func (e MessageEvent) MarshalJSON() ([]byte, error) {
	type s MessageEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeMessage})
}

// StateConnectionEvent represents connection state changes.
type StateConnectionEvent struct {
	BaseEvent
	State   ConnectionState `json:"state"`
	Message string          `json:"message"`
}

func (StateConnectionEvent) EventType() EventType { return EventTypeState }

func (e StateConnectionEvent) MarshalJSON() ([]byte, error) {
	type s StateConnectionEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventConnection})
}

// StateFrozenEvent represents conversation frozen state.
type StateFrozenEvent struct {
	BaseEvent
	ConversationID string         `json:"conversation_id"`
	Frozen         string         `json:"frozen"`
	Name           string         `json:"name,omitempty"`
	Topic          string         `json:"topic,omitempty"`
	Unread         int            `json:"unread,omitempty"`
	Info           map[string]any `json:"info,omitempty"`
}

func (StateFrozenEvent) EventType() EventType { return EventTypeState }

func (e StateFrozenEvent) MarshalJSON() ([]byte, error) {
	type s StateFrozenEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventFrozen})
}

// StateJoinEvent represents a user joining a channel.
type StateJoinEvent struct {
	BaseEvent
	ConversationID string `json:"conversation_id"`
	Nick           string `json:"nick"`
	Account        string `json:"account,omitempty"`
}

func (StateJoinEvent) EventType() EventType { return EventTypeState }

func (e StateJoinEvent) MarshalJSON() ([]byte, error) {
	type s StateJoinEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventJoin})
}

// StatePartEvent represents a user leaving a channel (PART or KICK).
type StatePartEvent struct {
	BaseEvent
	ConversationID string `json:"conversation_id"`
	Nick           string `json:"nick"`
	Message        string `json:"message,omitempty"`
	Kicker         string `json:"kicker,omitempty"`
}

func (StatePartEvent) EventType() EventType { return EventTypeState }

func (e StatePartEvent) MarshalJSON() ([]byte, error) {
	type s StatePartEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventPart})
}

// StateQuitEvent represents a user quitting the server.
type StateQuitEvent struct {
	BaseEvent
	Nick    string `json:"nick"`
	Message string `json:"message,omitempty"`
}

func (StateQuitEvent) EventType() EventType { return EventTypeState }

func (e StateQuitEvent) MarshalJSON() ([]byte, error) {
	type s StateQuitEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventQuit})
}

// Participant represents a channel participant.
type Participant struct {
	Nick     string `json:"nick"`
	Mode     string `json:"mode"`
	Account  string `json:"account,omitempty"`
	Realname string `json:"realname,omitempty"`
	User     string `json:"user,omitempty"`
	Host     string `json:"host,omitempty"`
}

// StateParticipantsEvent represents a participant list update.
type StateParticipantsEvent struct {
	BaseEvent
	ConversationID string        `json:"conversation_id"`
	Participants   []Participant `json:"participants"`
}

func (StateParticipantsEvent) EventType() EventType { return EventTypeState }

func (e StateParticipantsEvent) MarshalJSON() ([]byte, error) {
	type s StateParticipantsEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventParticipants})
}

// StateTypingEvent represents a typing indicator.
type StateTypingEvent struct {
	BaseEvent
	Nick           string `json:"nick"`
	ConversationID string `json:"conversation_id"`
	Typing         string `json:"typing"`
}

func (StateTypingEvent) EventType() EventType { return EventTypeState }

func (e StateTypingEvent) MarshalJSON() ([]byte, error) {
	type s StateTypingEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventTyping})
}

// StateNickChangeEvent represents a user changing their nickname.
type StateNickChangeEvent struct {
	BaseEvent
	OldNick string `json:"old_nick"`
	NewNick string `json:"new_nick"`
}

func (StateNickChangeEvent) EventType() EventType { return EventTypeState }

func (e StateNickChangeEvent) MarshalJSON() ([]byte, error) {
	type s StateNickChangeEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventNickChange})
}

// StateModeEvent represents a channel or user mode change.
type StateModeEvent struct {
	BaseEvent
	ConversationID string `json:"conversation_id"`
	From           string `json:"from"`
	Mode           string `json:"mode"`
	Nick           string `json:"nick,omitempty"`         // For user modes
	ModeChanged    bool   `json:"mode_changed,omitempty"` // For channel modes
	Args           string `json:"args,omitempty"`         // Mode arguments
}

func (StateModeEvent) EventType() EventType { return EventTypeState }

func (e StateModeEvent) MarshalJSON() ([]byte, error) {
	type s StateModeEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventMode})
}

// StateInviteEvent represents a user being invited to a channel.
type StateInviteEvent struct {
	BaseEvent
	ConversationID string `json:"conversation_id"`
	Nick           string `json:"nick"`
	Message        string `json:"message"`
}

func (StateInviteEvent) EventType() EventType { return EventTypeState }

func (e StateInviteEvent) MarshalJSON() ([]byte, error) {
	type s StateInviteEvent
	return marshalWithExtras(s(e), map[string]any{"event": EventTypeState, "type": StateEventInvite})
}

// StateInfoEvent represents a generic info event (user modes, connection info).
type StateInfoEvent struct {
	BaseEvent
	Info map[string]any `json:"-"`
}

func (StateInfoEvent) EventType() EventType { return EventTypeState }

// MarshalJSON inlines the Info map into the top-level JSON object.
func (e StateInfoEvent) MarshalJSON() ([]byte, error) {
	type s StateInfoEvent
	extras := map[string]any{"event": EventTypeState, "type": StateEventInfo}
	maps.Copy(extras, e.Info)
	return marshalWithExtras(s(e), extras)
}

// SentEvent represents a sent command response event.
type SentEvent struct {
	BaseEvent
	ConversationID string         `json:"conversation_id,omitempty"`
	Message        string         `json:"message,omitempty"`
	Command        []string       `json:"command"`
	Data           map[string]any `json:"-"` // Additional command-specific data, inlined by MarshalJSON
}

func (SentEvent) EventType() EventType { return EventTypeSent }

// MarshalJSON inlines the Data map into the top-level JSON object.
func (e SentEvent) MarshalJSON() ([]byte, error) {
	type s SentEvent
	extras := map[string]any{"event": EventTypeSent}
	maps.Copy(extras, e.Data)
	return marshalWithExtras(s(e), extras)
}
