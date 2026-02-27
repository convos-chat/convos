package core

import (
	"encoding/json"
	"testing"
)

const testUser = "alice"

// TestMessageEventSerialization verifies JSON output matches expected format.
func TestMessageEventSerialization(t *testing.T) {
	t.Parallel()
	ev := MessageEvent{
		BaseEvent: BaseEvent{
			ConnectionID: "irc-libera",
			TS:           "2024-01-01T12:00:00Z",
		},
		ConversationID: "#go-nuts",
		From:           testUser,
		Message:        "hello world",
		Type:           MessageTypePrivate,
		Highlight:      true,
		MsgID:          "msg-123",
	}

	data, err := json.Marshal(ev)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	// Verify required fields
	if m["event"] != "message" {
		t.Errorf("event = %v, want message", m["event"])
	}
	if m["from"] != testUser {
		t.Errorf("from = %v, want alice", m["from"])
	}
	if m["highlight"] != true {
		t.Errorf("highlight = %v, want true", m["highlight"])
	}
	if m["msgid"] != "msg-123" {
		t.Errorf("msgid = %v, want msg-123", m["msgid"])
	}
}

// TestOptionalFieldsOmitted verifies that empty optional fields are omitted from JSON.
func TestOptionalFieldsOmitted(t *testing.T) {
	t.Parallel()
	ev := MessageEvent{
		BaseEvent: BaseEvent{
			ConnectionID: "irc-libera",
			TS:           "2024-01-01T12:00:00Z",
		},
		ConversationID: "#test",
		From:           testUser,
		Message:        "test",
		Type:           MessageTypePrivate,
		Highlight:      false,
		// MsgID, Account, ReplyTo left empty
	}

	data, err := json.Marshal(ev)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	// Optional fields should not be present when empty
	if _, ok := m["msgid"]; ok {
		t.Error("msgid should be omitted when empty")
	}
	if _, ok := m["account"]; ok {
		t.Error("account should be omitted when empty")
	}
	if _, ok := m["reply_to"]; ok {
		t.Error("reply_to should be omitted when empty")
	}
}

// TestStateInfoEventInlining verifies that StateInfoEvent.Info fields are
// inlined into the top-level JSON object rather than nested under a key.
func TestStateInfoEventInlining(t *testing.T) {
	t.Parallel()
	ev := StateInfoEvent{
		BaseEvent: BaseEvent{
			ConnectionID: "irc-libera",
			TS:           "2024-01-01T12:00:00Z",
		},
		Info: map[string]any{
			"nick": testUser,
			"mode": "+i",
		},
	}

	data, err := json.Marshal(ev)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	// Info fields must appear at the top level, not nested under ""
	if m["nick"] != testUser {
		t.Errorf("nick = %v, want alice (Info fields must be inlined into top-level JSON)", m["nick"])
	}
	if m["mode"] != "+i" {
		t.Errorf("mode = %v, want +i (Info fields must be inlined into top-level JSON)", m["mode"])
	}
	if _, bad := m[""]; bad {
		t.Error(`Info was serialized under key "" instead of being inlined`)
	}
}

// TestSentEventInlining verifies that SentEvent.Data fields are inlined into
// the top-level JSON object rather than nested under a key.
func TestSentEventInlining(t *testing.T) {
	t.Parallel()
	ev := SentEvent{
		BaseEvent: BaseEvent{
			ConnectionID: "irc-libera",
			TS:           "2024-01-01T12:00:00Z",
		},
		Command: []string{"whois"},
		Data: map[string]any{
			"nick": testUser,
			"host": "example.com",
		},
	}

	data, err := json.Marshal(ev)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	// Data fields must appear at the top level, not nested under ""
	if m["nick"] != testUser {
		t.Errorf("nick = %v, want alice (Data fields must be inlined into top-level JSON)", m["nick"])
	}
	if m["host"] != "example.com" {
		t.Errorf("host = %v, want example.com (Data fields must be inlined into top-level JSON)", m["host"])
	}
	if _, bad := m[""]; bad {
		t.Error(`Data was serialized under key "" instead of being inlined`)
	}
}

// TestStateConnectionEventSerialization tests state connection events.
func TestStateConnectionEventSerialization(t *testing.T) {
	t.Parallel()
	ev := StateConnectionEvent{
		BaseEvent: BaseEvent{
			ConnectionID: "irc-libera",
			TS:           "2024-01-01T12:00:00Z",
		},
		State:   StateConnected,
		Message: "Connected to server",
	}

	data, err := json.Marshal(ev)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	if m["event"] != "state" {
		t.Errorf("event = %v, want state", m["event"])
	}
	if m["type"] != "connection" {
		t.Errorf("type = %v, want connection", m["type"])
	}
	if m["message"] != "Connected to server" {
		t.Errorf("message = %v, want Connected to server", m["message"])
	}
}
