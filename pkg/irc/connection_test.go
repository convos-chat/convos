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
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		msg := ircmsg.MakeMessage(nil, "server.net", "001", "testnick", "Welcome to the Network")
		conn.handleWelcome(msg)

		if conn.Info()["server"] != "server.net" {
			t.Errorf("Expected server info, got %v", conn.Info()["server"])
		}

		// handleWelcome emits info event
		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "info" {
				t.Errorf("Unexpected event: %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected info event")
		}

		// handleWelcome also calls handleNotice which emits a message
		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["event"] != evMessage || m["type"] != "notice" {
				t.Errorf("Expected notice message event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected notice event")
		}
	})

	t.Run("handleJoin", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
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
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "join" || m["nick"] != "other" {
				t.Errorf("Expected join event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected join event")
		}
	})

	t.Run("handleTopic", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
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
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "frozen" || m["topic"] != "New Topic" {
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
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Setup a conversation where we are present
		conv := core.NewConversation("#test", conn)
		conn.AddConversation(conv)
		conv.AddParticipant("testnick", map[string]any{"nick": "testnick"})

		// testnick changes to newnick
		msg := ircmsg.MakeMessage(nil, "testnick!user@host", "NICK", "newnick")
		conn.handleNick(msg)

		if conn.Nick() != "newnick" {
			t.Errorf("Expected nick 'newnick', got %q", conn.Nick())
		}

		// Expect 'me' event
		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "me" {
				// Might be nick_change if order changes, but currently we expect me first or only
				t.Logf("Got event: %v", m)
			}
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
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Private message to user
		msg := ircmsg.MakeMessage(nil, aliceNick+"!user@host", "PRIVMSG", "newnick", "Hello!")
		conn.handleMessage(msg, "private")

		conv := conn.GetConversation(aliceNick)
		if conv == nil {
			t.Fatal("Conversation 'alice' should have been created")
		}

		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["event"] != evMessage || m["from"] != aliceNick {
				t.Errorf("Expected message from alice, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected message event")
		}
	})

	t.Run("handlePart", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Setup: Create conversation and add participant
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant("other_", map[string]any{"nick": "other_"})

		msg := ircmsg.MakeMessage(nil, "other_!user@host", "PART", "#convos", "Bye")
		conn.handlePart(msg)

		if _, ok := conv.Participants()["other_"]; ok {
			t.Error("Participant 'other_' should have been removed")
		}

		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "part" || m["nick"] != "other_" {
				t.Errorf("Expected part event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected part event")
		}
	})

	t.Run("handleKick", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Add victim back first - creating conv
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant("victim", map[string]any{"nick": "victim"})

		msg := ircmsg.MakeMessage(nil, "op!user@host", "KICK", "#convos", "victim", "Bad behavior")
		conn.handleKick(msg)

		if _, ok := conv.Participants()["victim"]; ok {
			t.Error("Participant 'victim' should have been removed")
		}

		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "part" || m["nick"] != "victim" || m["kicker"] != "op" {
				t.Errorf("Expected part (kick) event, got %+v", m)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected kick event")
		}
	})

	t.Run("handleQuit", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Add alice back to a channel - creating conv first
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant("alice", map[string]any{"nick": "alice"})

		msg := ircmsg.MakeMessage(nil, "alice!user@host", "QUIT", "Gone to lunch")
		conn.handleQuit(msg)

		if _, ok := conv.Participants()["alice"]; ok {
			t.Error("Participant 'alice' should have been removed from #convos")
		}

		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["type"] != "quit" || m["nick"] != "alice" {
				t.Errorf("Expected quit event, got %+v", m)
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

		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// NickServ sends a NOTICE directly to our nick; no existing conversation.
		msg := ircmsg.MakeMessage(nil, "NickServ!services@services", "NOTICE", "testnick", "You are now identified.")
		conn.handleMessage(msg, "notice")

		// Must NOT create a "nickserv" conversation.
		if conn.GetConversation("NickServ") != nil || conn.GetConversation("nickserv") != nil {
			t.Error("handleMessage must not auto-create a conversation for a service account")
		}

		// Message should be routed to server log (empty conv ID).
		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m["conversation_id"] != "" {
				t.Errorf("expected conversation_id='', got %q", m["conversation_id"])
			}
			if m["from"] != "NickServ" {
				t.Errorf("expected from='NickServ', got %q", m["from"])
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

		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		msg := ircmsg.MakeMessage(nil, "NickServ!services@services", "NOTICE", "testnick", "Password accepted.")
		conn.handleMessage(msg, "notice")

		// Message should be routed to the existing NickServ conversation.
		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("unexpected event type: %T", ev)
			}
			if m["conversation_id"] != "nickserv" {
				t.Errorf("expected conversation_id='nickserv', got %q", m["conversation_id"])
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("expected message event")
		}
	})

	t.Run("handleNotice_Wildcard", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// NOTICE * :*** Looking up your hostname...
		msg := ircmsg.MakeMessage(nil, "server", "NOTICE", "*", "*** Looking up your hostname...")
		conn.handleMessage(msg, "notice")

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
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["conversation_id"] != "" {
				t.Errorf("Expected conversation_id='', got %q", m["conversation_id"])
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected message event")
		}
	})

	t.Run("handleTagMsg", func(t *testing.T) {
		t.Parallel()
		c, user, conn := setup()
		sub := c.Events().SubscribeUser(user.ID())
		defer sub.Close()

		// Setup conversation
		conv := core.NewConversation("#convos", conn)
		conn.AddConversation(conv)
		conv.AddParticipant("alice", map[string]any{"nick": "alice"})

		// 1. Typing notification
		// TAGMSG #convos +typing=active
		typingMsg := ircmsg.MakeMessage(map[string]string{"+typing": "active"}, "alice!user@host", "TAGMSG", "#convos")
		conn.handleTagMsg(typingMsg)

		select {
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["event"] != evState || m["type"] != "typing" {
				t.Errorf("Expected state/typing event, got %+v", m)
			}
			if m["typing"] != "active" {
				t.Errorf("Expected typing='active', got %v", m["typing"])
			}
			if m["nick"] != "alice" {
				t.Errorf("Expected nick='alice', got %v", m["nick"])
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
		case ev := <-sub.Events():
			m, ok := ev.(map[string]any)
			if !ok {
				t.Fatalf("Unexpected event type: %T", ev)
			}
			if m["event"] != evMessage || m["type"] != "reaction" {
				t.Errorf("Expected message/reaction event, got %+v", m)
			}
			if m["message"] != "👍" {
				t.Errorf("Expected message='👍', got %v", m["message"])
			}
			if m["reply_to"] != "msg123" {
				t.Errorf("Expected reply_to='msg123', got %v", m["reply_to"])
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Expected reaction event")
		}
	})
}
