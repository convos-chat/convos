package irc

import (
	"context"
	"errors"
	"net"
	"net/url"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
	"github.com/ergochat/irc-go/ircmsg"
)

var errDialDisabled = errors.New("dial disabled in test")

func TestNewConnectionIgnoreWaitersInitialised(t *testing.T) {
	t.Parallel()
	c := test.NewTestCore()
	user := core.NewUser("test@example.com", c)
	conn := NewConnection("irc://irc.libera.chat", user)
	if len(conn.ignoreWaiters) != 0 {
		t.Errorf("ignoreWaiters should be empty on construction, got %d entries", len(conn.ignoreWaiters))
	}
	// Verify the map is writable (not nil).
	conn.ignoreWaiters["testnick"] = "TestNick"
	if conn.ignoreWaiters["testnick"] != "TestNick" {
		t.Error("ignoreWaiters should be writable after construction")
	}
}

var failDialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
	return nil, errDialDisabled
}

func mustParseURL(raw string) *url.URL {
	u, err := url.Parse(raw)
	if err != nil {
		panic(err)
	}
	return u
}

func TestIRCConnection_Handlers(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *core.User, *Connection) {
		c := test.NewTestCore()
		user := core.NewUser("test@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		return c, user, conn
	}

	t.Run("handleWelcome", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		msg := ircmsg.MakeMessage(nil, "server.net", "001", "testnick", "Welcome to the Network")
		conn.handleWelcome(msg)

		if conn.Info()["server"] != "server.net" {
			t.Errorf("Expected server info, got %v", conn.Info()["server"])
		}

		// handleWelcome emits info event
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StateInfoEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.EventType() != core.EventTypeState {
				t.Errorf("Unexpected event: %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected info event")
		}

		// handleWelcome also calls handleNotice which emits a message
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Type != core.MessageTypeNotice {
				t.Errorf("Expected notice message event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected notice event")
		}
	})

	t.Run("handleJoin", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Mock current nick since client is nil
		conn.nick = "testnick"

		// Someone else joins
		msg := ircmsg.MakeMessage(nil, "other!user@host", "JOIN", "#convos")
		conn.handleJoin(msg)

		conv := conn.GetConversation("#convos")
		if conv == nil {
			t.Fatal("Conversation #convos should have been created")
		}
		if _, ok := conv.Participants()["other"]; !ok {
			t.Error("Participant 'other' should have been added")
		}

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StateJoinEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Nick != "other" {
				t.Errorf("Expected join event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected join event")
		}
	})

	t.Run("handleTopic", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Create conversation first
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)

		msg := ircmsg.MakeMessage(nil, "op!user@host", "TOPIC", "#convos", "New Topic")
		conn.handleTopic(msg)

		if conv.Topic() != "New Topic" {
			t.Errorf("Expected topic 'New Topic', got %q", conv.Topic())
		}

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StateFrozenEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Topic != "New Topic" {
				t.Errorf("Expected frozen event with topic, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected topic event")
		}
	})

	t.Run("handleNick", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		conn.SetNick("testnick") // Force current nick to match
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Setup a conversation where we are present
		conv := core.NewConversation("#test", conn)
		conn.AddConversation(conv)
		conv.AddParticipant(core.Participant{Nick: "testnick"})

		// testnick changes to newnick
		msg := ircmsg.MakeMessage(nil, "testnick!user@host", "NICK", "newnick")
		conn.handleNick(msg)

		if conn.Nick() != "newnick" {
			t.Errorf("Expected nick 'newnick', got %q", conn.Nick())
		}

		// Expect 'me' event
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StateInfoEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			_ = m // StateInfoEvent confirmed by type assertion; Info map content varies
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected event")
		}

		// Check if conversation participant was updated
		if _, ok := conv.Participants()["newnick"]; !ok {
			t.Error("Participant 'newnick' should have been added to conversation")
		}
		if _, ok := conv.Participants()["testnick"]; ok {
			t.Error("Participant 'testnick' should have been removed from conversation")
		}
	})

	t.Run("handleMessage", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		conn.SetNick("newnick") // Force current nick to match target
		const aliceNick = "alice"
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Private message to user
		msg := ircmsg.MakeMessage(nil, aliceNick+"!user@host", "PRIVMSG", "newnick", "Hello!")
		conn.handleMessage(msg, core.MessageTypePrivate)

		conv := conn.GetConversation(aliceNick)
		if conv == nil {
			t.Fatal("Conversation 'alice' should have been created")
		}

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.From != aliceNick {
				t.Errorf("Expected message from alice, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected message event")
		}
	})

	t.Run("handleMessage_ircv3_tags", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		conn.SetNick("testnick")
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// PRIVMSG with msgid, account, and +draft/reply tags
		msg := ircmsg.MakeMessage(
			map[string]string{
				"msgid":        "abc-123",
				"account":      "alice_account",
				"+draft/reply": "parent-msg-456",
			},
			"alice!user@host", "PRIVMSG", "#convos", "Hello with tags!",
		)
		conn.AddConversation(core.NewConversation("#convos", conn))
		conn.handleMessage(msg, core.MessageTypePrivate)

		// Check emitted event
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m.MsgID != "abc-123" {
				t.Errorf("expected msgid=abc-123, got %v", m.MsgID)
			}
			if m.Account != "alice_account" {
				t.Errorf("expected account=alice_account, got %v", m.Account)
			}
			if m.ReplyTo != "parent-msg-456" {
				t.Errorf("expected reply_to=parent-msg-456, got %v", m.ReplyTo)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatal("expected message event")
		}

		// Check persisted message has MsgID, Account, ReplyTo
		conv := conn.GetConversation("#convos")
		if conv == nil {
			t.Fatal("conversation #convos not found")
		}
		result, err := c.Backend.LoadMessages(conv, core.MessageQuery{Limit: 10})
		if err != nil {
			t.Fatalf("LoadMessages: %v", err)
		}
		if len(result.Messages) == 0 {
			t.Fatal("expected at least one persisted message")
		}
		saved := result.Messages[len(result.Messages)-1]
		if saved.MsgID != "abc-123" {
			t.Errorf("persisted MsgID: want abc-123, got %q", saved.MsgID)
		}
		if saved.Account != "alice_account" {
			t.Errorf("persisted Account: want alice_account, got %q", saved.Account)
		}
		if saved.ReplyTo != "parent-msg-456" {
			t.Errorf("persisted ReplyTo: want parent-msg-456, got %q", saved.ReplyTo)
		}
	})

	t.Run("handleMessage_no_tags", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		conn.SetNick("testnick")
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		conn.AddConversation(core.NewConversation("#convos", conn))
		msg := ircmsg.MakeMessage(nil, "bob!user@host", "PRIVMSG", "#convos", "plain message")
		conn.handleMessage(msg, core.MessageTypePrivate)

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m.MsgID != "" {
				t.Errorf("expected no msgid field, got %v", m.MsgID)
			}
			if m.Account != "" {
				t.Errorf("expected no account field, got %v", m.Account)
			}
			if m.ReplyTo != "" {
				t.Errorf("expected no reply_to field, got %v", m.ReplyTo)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatal("expected message event")
		}
	})

	t.Run("handlePart", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Setup: Create conversation and add participant
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant(core.Participant{Nick: "other_"})

		msg := ircmsg.MakeMessage(nil, "other_!user@host", "PART", "#convos", "Bye")
		conn.handlePart(msg)

		if _, ok := conv.Participants()["other_"]; ok {
			t.Error("Participant 'other_' should have been removed")
		}

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StatePartEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Nick != "other_" {
				t.Errorf("Expected part event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected part event")
		}
	})

	t.Run("handleKick", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Add victim back first - creating conv
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant(core.Participant{Nick: "victim"})

		msg := ircmsg.MakeMessage(nil, "op!user@host", "KICK", "#convos", "victim", "Bad behavior")
		conn.handleKick(msg)

		if _, ok := conv.Participants()["victim"]; ok {
			t.Error("Participant 'victim' should have been removed")
		}

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StatePartEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Nick != "victim" || m.Kicker != "op" {
				t.Errorf("Expected part (kick) event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected kick event")
		}
	})

	t.Run("handleQuit", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Add alice back to a channel - creating conv first
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant(core.Participant{Nick: "alice"})

		msg := ircmsg.MakeMessage(nil, "alice!user@host", "QUIT", "Gone to lunch")
		conn.handleQuit(msg)

		if _, ok := conv.Participants()["alice"]; ok {
			t.Error("Participant 'alice' should have been removed from #convos")
		}

		select {
		case ev := <-sub.Events:
			_, ok := ev.(*core.StateQuitEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected quit event")
		}
	})

	t.Run("isHighlight", func(t *testing.T) {
		t.Parallel()
		_, user, conn := setup()
		conn.nick = "my-nick"
		user.SetHighlightKeywords([]string{"alert", "urgent"})

		if !conn.isHighlight("hello my-nick!") {
			t.Error("Should highlight own nick")
		}
		if !conn.isHighlight("this is an alert") {
			t.Error("Should highlight keyword 'alert'")
		}
		if conn.isHighlight("just a normal message") {
			t.Error("Should not highlight normal message")
		}
	})

	t.Run("Connect_SASL_PLAIN", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.SetURL(mustParseURL("irc://myuser:secret@irc.example.com:6697/?sasl=plain&nick=yolo&tls=0"))
		conn.DialContext = failDialContext

		_ = conn.Connect() // will fail to dial, but client is configured

		if conn.client == nil {
			t.Fatal("client should be set")
		}
		if !conn.client.UseSASL {
			t.Error("UseSASL should be true")
		}
		if conn.client.SASLMech != "PLAIN" {
			t.Errorf("SASLMech = %q, want PLAIN", conn.client.SASLMech)
		}
		if conn.client.SASLLogin != "myuser" {
			t.Errorf("SASLLogin = %q, want myuser", conn.client.SASLLogin)
		}
		if conn.client.SASLPassword != "secret" {
			t.Errorf("SASLPassword = %q, want secret", conn.client.SASLPassword)
		}
		if conn.client.Password != "" {
			t.Errorf("Password should be empty when SASL is used, got %q", conn.client.Password)
		}
	})

	t.Run("Connect_SASL_PLAIN_no_username", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.SetURL(mustParseURL("irc://:secret2@irc.example.com:6697/?sasl=plain&nick=yolo&tls=0"))
		conn.DialContext = failDialContext

		_ = conn.Connect()

		if conn.client.SASLLogin != "yolo" {
			t.Errorf("SASLLogin should fall back to nick, got %q", conn.client.SASLLogin)
		}
		if conn.client.SASLPassword != "secret2" {
			t.Errorf("SASLPassword = %q, want secret2", conn.client.SASLPassword)
		}
	})

	t.Run("Connect_SASL_EXTERNAL", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.SetURL(mustParseURL("irc://certuser:@irc.example.com/?sasl=external&nick=yolo&tls=0"))
		conn.DialContext = failDialContext

		_ = conn.Connect()

		if conn.client.SASLMech != "EXTERNAL" {
			t.Errorf("SASLMech = %q, want EXTERNAL", conn.client.SASLMech)
		}
		if conn.client.SASLLogin != "certuser" {
			t.Errorf("SASLLogin = %q, want certuser", conn.client.SASLLogin)
		}
	})

	t.Run("Connect_no_SASL_with_password", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.SetURL(mustParseURL("irc://:serverpass@irc.example.com/?nick=yolo&tls=0"))
		conn.DialContext = failDialContext

		_ = conn.Connect()

		if conn.client.UseSASL {
			t.Error("UseSASL should be false without sasl param")
		}
		if conn.client.Password != "serverpass" {
			t.Errorf("Password = %q, want serverpass", conn.client.Password)
		}
	})

	t.Run("Connect_no_auth", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.SetURL(mustParseURL("irc://irc.example.com/?nick=yolo&tls=0"))
		conn.DialContext = failDialContext

		_ = conn.Connect()

		if conn.client.UseSASL {
			t.Error("UseSASL should be false")
		}
		if conn.client.Password != "" {
			t.Errorf("Password should be empty, got %q", conn.client.Password)
		}
	})

	t.Run("parseNickMode", func(t *testing.T) {
		t.Parallel()
		tests := []struct {
			raw  string
			mode string
			nick string
		}{
			{"@op", "o", "op"},
			{"+voice", "v", "voice"},
			{"~founder", "q", "founder"},
			{"&admin", "a", "admin"},
			{"%half", "h", "half"},
			{"normal", "", "normal"},
		}
		for _, tt := range tests {
			m, n := parseNickMode(tt.raw)
			if m != tt.mode || n != tt.nick {
				t.Errorf("parseNickMode(%q) = (%q, %q), want (%q, %q)", tt.raw, m, n, tt.mode, tt.nick)
			}
		}
	})

	t.Run("handleMessage_ServiceAccount_no_existing_conv", func(t *testing.T) {
		t.Parallel()
		// Core configured with NickServ as a service account.
		c := core.New(core.WithBackend(test.NewMemoryBackend()), core.WithProfileDefaults(0, 0, []string{"nickserv"}))
		user := core.NewUser("test@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		conn.SetNick("testnick")

		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// NickServ sends a NOTICE directly to our nick; no existing conversation.
		msg := ircmsg.MakeMessage(nil, "NickServ!services@services", "NOTICE", "testnick", "You are now identified.")
		conn.handleMessage(msg, core.MessageTypeNotice)

		// Must NOT create a "nickserv" conversation.
		if conn.GetConversation("NickServ") != nil || conn.GetConversation("nickserv") != nil {
			t.Error("handleMessage must not auto-create a conversation for a service account")
		}

		// Message should be routed to server log (empty conv ID).
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m.ConversationID != "" {
				t.Errorf("expected conversation_id='', got %q", m.ConversationID)
			}
			if m.From != "NickServ" {
				t.Errorf("expected from='NickServ', got %q", m.From)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("expected message event")
		}
	})

	t.Run("handleMessage_ServiceAccount_existing_conv", func(t *testing.T) {
		t.Parallel()
		c := core.New(core.WithBackend(test.NewMemoryBackend()), core.WithProfileDefaults(0, 0, []string{"nickserv"}))
		user := core.NewUser("test@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		conn.SetNick("testnick")

		// Pre-open a NickServ conversation.
		nsConv := core.NewConversation("nickserv", conn)
		conn.AddConversation(nsConv)

		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		msg := ircmsg.MakeMessage(nil, "NickServ!services@services", "NOTICE", "testnick", "Password accepted.")
		conn.handleMessage(msg, core.MessageTypeNotice)

		// Message should be routed to the existing NickServ conversation.
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m.ConversationID != "nickserv" {
				t.Errorf("expected conversation_id='nickserv', got %q", m.ConversationID)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("expected message event")
		}
	})

	t.Run("handleNotice_Wildcard", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// NOTICE * :*** Looking up your hostname...
		msg := ircmsg.MakeMessage(nil, "server", "NOTICE", "*", "*** Looking up your hostname...")
		conn.handleMessage(msg, core.MessageTypeNotice)

		// Should NOT create a conversation named "*"
		if conn.GetConversation("*") != nil {
			t.Error("Should not create conversation '*'")
		}

		// Should be routed to server conversation (empty ID)
		serverConv := conn.GetConversation("")
		if serverConv == nil {
			t.Fatal("Should create server conversation (empty ID)")
		}

		// Check event
		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.ConversationID != "" {
				t.Errorf("Expected conversation_id='', got %q", m.ConversationID)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected message event")
		}
	})

	t.Run("handleTagMsg", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		// Setup conversation
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant(core.Participant{Nick: "alice"})

		// 1. Typing notification
		// TAGMSG #convos +typing=active
		typingMsg := ircmsg.MakeMessage(map[string]string{"+typing": "active"}, "alice!user@host", "TAGMSG", "#convos")
		conn.handleTagMsg(typingMsg)

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.StateTypingEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Typing != "active" {
				t.Errorf("Expected typing='active', got %v", m.Typing)
			}
			if m.Nick != "alice" {
				t.Errorf("Expected nick='alice', got %v", m.Nick)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected typing event")
		}

		// 2. Reaction
		// TAGMSG #convos +draft/reply=msg123 +draft/react=👍
		reactMsg := ircmsg.MakeMessage(map[string]string{
			"+draft/reply": "msg123",
			"+draft/react": "👍",
		}, "alice!user@host", "TAGMSG", "#convos")
		conn.handleTagMsg(reactMsg)

		select {
		case ev := <-sub.Events:
			m, ok := ev.(*core.MessageEvent)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m.Type != core.MessageTypeReaction {
				t.Errorf("Expected message/reaction event, got %+v", m)
			}
			if m.Message != "👍" {
				t.Errorf("Expected message='👍', got %v", m.Message)
			}
			if m.ReplyTo != "msg123" {
				t.Errorf("Expected reply_to='msg123', got %v", m.ReplyTo)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected reaction event")
		}
	})
}

func TestHandleEndOfWhoisIgnoreWaiter(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()
	user := core.NewUser("test@example.com", c)
	conn := NewConnection("irc://irc.libera.chat", user)
	sub := c.EventEmitter.SubscribeUser(user.ID())
	defer sub.Close()

	// Simulate a WHOIS reply populating the buffer
	conn.mu.Lock()
	conn.whoisBuffer["badnick"] = &core.WhoisData{
		Nick:     "BadNick",
		User:     "baduser",
		Host:     "evil.host",
		Channels: make(map[string]any),
	}
	conn.ignoreWaiters["badnick"] = "BadNick"
	conn.mu.Unlock()

	// Simulate RPL_ENDOFWHOIS
	msg := ircmsg.MakeMessage(nil, "server.net", "318", "me", "BadNick", "End of WHOIS list")
	conn.handleEndOfWhois(msg)

	// Expect both an ignore-confirmation SentEvent and a normal whois SentEvent.
	var gotIgnoreEvent, gotWhoisEvent bool
	deadline := time.After(200 * time.Millisecond)
	for !gotIgnoreEvent || !gotWhoisEvent {
		select {
		case ev := <-sub.Events:
			if sent, ok := ev.(*core.SentEvent); ok && len(sent.Command) > 0 {
				switch sent.Command[0] {
				case "ignore":
					gotIgnoreEvent = true
				case "whois":
					gotWhoisEvent = true
				}
			}
		case <-deadline:
			t.Fatalf("timed out waiting for events: gotIgnore=%v gotWhois=%v", gotIgnoreEvent, gotWhoisEvent)
		}
	}

	// Mask should be stored on user
	masks := user.IgnoreMasks()
	if masks["BadNick"] != "*!baduser@evil.host" {
		t.Errorf("IgnoreMasks() = %v, want BadNick → *!baduser@evil.host", masks)
	}

	// Waiter should be cleared
	conn.mu.RLock()
	_, still := conn.ignoreWaiters["badnick"]
	conn.mu.RUnlock()
	if still {
		t.Error("ignoreWaiters should be cleared after WHOIS completes")
	}
}

func TestIgnoreFiltering(t *testing.T) {
	t.Parallel()

	const spammerNick = "Spammer"
	const spammerNUH = "Spammer!spam@evil.host"

	setup := func() (*Connection, *core.Subscription) {
		c := test.NewTestCore()
		user := core.NewUser("test@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		conn.nick = "me"
		sub := c.EventEmitter.SubscribeUser(user.ID())
		user.AddIgnoreMask(spammerNick, "*!spam@evil.host")
		return conn, sub
	}

	drain := func(sub *core.Subscription) []core.Event {
		var evs []core.Event
		for {
			select {
			case ev := <-sub.Events:
				evs = append(evs, ev)
			case <-time.After(50 * time.Millisecond):
				return evs
			}
		}
	}

	t.Run("handleMessage drops ignored PRIVMSG", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		conn.AddConversation(core.NewConversation("#test", conn))
		msg := ircmsg.MakeMessage(nil, spammerNUH, "PRIVMSG", "#test", "hello")
		conn.handleMessage(msg, core.MessageTypePrivate)

		evs := drain(sub)
		for _, ev := range evs {
			if me, ok := ev.(*core.MessageEvent); ok && me.From == spammerNick {
				t.Errorf("ignored sender's message was emitted: %+v", me)
			}
		}
	})

	t.Run("handleMessage passes non-ignored PRIVMSG", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		conn.AddConversation(core.NewConversation("#test", conn))
		msg := ircmsg.MakeMessage(nil, "GoodUser!good@good.host", "PRIVMSG", "#test", "hello")
		conn.handleMessage(msg, core.MessageTypePrivate)

		evs := drain(sub)
		var found bool
		for _, ev := range evs {
			if me, ok := ev.(*core.MessageEvent); ok && me.From == "GoodUser" {
				found = true
			}
		}
		if !found {
			t.Error("non-ignored sender's message was not emitted")
		}
	})

	t.Run("handleJoin drops ignored join", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		conn.AddConversation(core.NewConversation("#test", conn))
		msg := ircmsg.MakeMessage(nil, spammerNUH, "JOIN", "#test")
		conn.handleJoin(msg)

		evs := drain(sub)
		for _, ev := range evs {
			if je, ok := ev.(*core.StateJoinEvent); ok && je.Nick == spammerNick {
				t.Errorf("ignored sender's join was emitted: %+v", je)
			}
		}
	})

	t.Run("handleQuit drops ignored quit but removes participant", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		// Add spammer as a participant so we can verify they are removed.
		conv := core.NewConversation("#test", conn)
		conv.AddParticipant(core.Participant{Nick: spammerNick})
		conn.AddConversation(conv)

		msg := ircmsg.MakeMessage(nil, spammerNUH, "QUIT", "Bye")
		conn.handleQuit(msg)

		// Event should be suppressed.
		evs := drain(sub)
		for _, ev := range evs {
			if qe, ok := ev.(*core.StateQuitEvent); ok && qe.Nick == spammerNick {
				t.Errorf("ignored sender's quit was emitted: %+v", qe)
			}
		}

		// Participant must be removed from the roster.
		if _, ok := conv.Participants()[spammerNick]; ok {
			t.Error("ignored quitter should be removed from participant list")
		}
	})

	t.Run("handlePart drops ignored part", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		conn.AddConversation(core.NewConversation("#test", conn))
		msg := ircmsg.MakeMessage(nil, spammerNUH, "PART", "#test", "bye")
		conn.handlePart(msg)

		evs := drain(sub)
		for _, ev := range evs {
			if pe, ok := ev.(*core.StatePartEvent); ok && pe.Nick == spammerNick {
				t.Errorf("ignored sender's part was emitted: %+v", pe)
			}
		}
	})

	t.Run("handleNick drops ignored nick change", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()

		msg := ircmsg.MakeMessage(nil, spammerNUH, "NICK", "SpammerRenamed")
		conn.handleNick(msg)

		evs := drain(sub)
		for _, ev := range evs {
			if ne, ok := ev.(*core.StateNickChangeEvent); ok && ne.OldNick == spammerNick {
				t.Errorf("ignored sender's nick change was emitted: %+v", ne)
			}
		}
	})

	t.Run("handleNick does not suppress own nick change", func(t *testing.T) {
		t.Parallel()
		conn, sub := setup()
		defer sub.Close()
		conn.nick = "me"

		// Own nick change: sender is "me!myident@myhost" → "me2"
		msg := ircmsg.MakeMessage(nil, "me!myident@myhost", "NICK", "me2")
		conn.handleNick(msg)

		evs := drain(sub)
		var gotNickChange bool
		for _, ev := range evs {
			if ne, ok := ev.(*core.StateNickChangeEvent); ok && ne.OldNick == "me" {
				gotNickChange = true
			}
		}
		if !gotNickChange {
			t.Error("own nick change event was suppressed")
		}
	})
}

func TestHandleIgnoreCommand(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *core.User, *Connection) {
		c := test.NewTestCore()
		user := core.NewUser("test@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		return c, user, conn
	}

	t.Run("list empty", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		err := conn.handleCommand("", "IGNORE", nil)
		if err != nil {
			t.Fatalf("handleCommand(IGNORE) error: %v", err)
		}

		select {
		case ev := <-sub.Events:
			sent, ok := ev.(*core.SentEvent)
			if !ok {
				t.Fatalf("expected SentEvent, got %T", ev)
			}
			if len(sent.Command) == 0 || sent.Command[0] != "ignore" {
				t.Errorf("expected command=[ignore], got %v", sent.Command)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("expected SentEvent for /ignore list")
		}
	})

	t.Run("self-ignore returns error", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.nick = "myNick"

		err := conn.handleCommand("", "IGNORE myNick", nil)
		if !errors.Is(err, ErrCannotIgnoreSelf) {
			t.Errorf("expected ErrCannotIgnoreSelf, got %v", err)
		}
	})

	t.Run("ignore nick when disconnected returns ErrNotConnected", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()
		conn.nick = "me"

		err := conn.handleCommand("", "IGNORE SomeNick", nil)
		if !errors.Is(err, ErrNotConnected) {
			t.Errorf("expected ErrNotConnected, got %v", err)
		}
	})

	t.Run("unignore blank returns error", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()

		err := conn.handleCommand("", "UNIGNORE", nil)
		if !errors.Is(err, ErrUsageUnignore) {
			t.Errorf("expected ErrUsageUnignore, got %v", err)
		}
	})

	t.Run("unignore unknown nick returns error", func(t *testing.T) {
		t.Parallel()
		_, _, conn := setup()

		err := conn.handleCommand("", "UNIGNORE UnknownNick", nil)
		if err == nil {
			t.Error("expected error for unknown nick, got nil")
		}
	})

	t.Run("unignore is case-insensitive", func(t *testing.T) {
		t.Parallel()
		_, user, conn := setup()

		user.AddIgnoreMask("BadNick", "*!bad@host")

		// "/unignore badnick" should match the key stored as "BadNick".
		err := conn.handleCommand("", "UNIGNORE badnick", nil)
		if err != nil {
			t.Fatalf("UNIGNORE with mismatched case error: %v", err)
		}
		if len(user.IgnoreMasks()) != 0 {
			t.Error("expected ignore mask to be removed by case-insensitive unignore")
		}
	})

	t.Run("unignore removes mask and emits event", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.EventEmitter.SubscribeUser(user.ID())
		defer sub.Close()

		user.AddIgnoreMask("BadNick", "*!bad@host")

		err := conn.handleCommand("", "UNIGNORE BadNick", nil)
		if err != nil {
			t.Fatalf("UNIGNORE error: %v", err)
		}

		if len(user.IgnoreMasks()) != 0 {
			t.Error("expected ignore mask to be removed")
		}

		select {
		case ev := <-sub.Events:
			sent, ok := ev.(*core.SentEvent)
			if !ok {
				t.Fatalf("expected SentEvent, got %T", ev)
			}
			if len(sent.Command) == 0 || sent.Command[0] != "unignore" {
				t.Errorf("expected command=[unignore], got %v", sent.Command)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("expected SentEvent for /unignore")
		}
	})
}

func TestDefaultNickFromEmail(t *testing.T) {
	t.Parallel()

	tests := []struct {
		email    string
		expected string
	}{
		{"john.doe@example.com", "john_doe"},
		{"alice@example.com", "alice"},
		{"test-user@example.com", "test_user"},
		{"no-at-sign", "guest"},
		{"@example.com", "guest"},
	}

	for _, tt := range tests {
		if got := defaultNickFromEmail(tt.email); got != tt.expected {
			t.Errorf("defaultNickFromEmail(%q) = %q, want %q", tt.email, got, tt.expected)
		}
	}
}

func TestNewConnectionNickInjection(t *testing.T) {
	t.Parallel()

	c := test.NewTestCore()

	t.Run("injects nick from email when absent", func(t *testing.T) {
		t.Parallel()
		user := core.NewUser("john.doe@example.com", c)
		conn := NewConnection("irc://irc.libera.chat", user)
		if got := conn.NickFromURL(); got != "john_doe" {
			t.Errorf("NickFromURL() = %q, want %q", got, "john_doe")
		}
	})

	t.Run("preserves existing nick in URL", func(t *testing.T) {
		t.Parallel()
		user := core.NewUser("john.doe@example.com", c)
		conn := NewConnection("irc://irc.libera.chat?nick=mynick", user)
		if got := conn.NickFromURL(); got != "mynick" {
			t.Errorf("NickFromURL() = %q, want %q", got, "mynick")
		}
	})
}
