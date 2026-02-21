package irc

import (
	"fmt"
	"math/rand/v2"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

// ircIntegrationEnv is the environment variable that enables IRC integration tests.
// Set it to a full IRC server URL, e.g.:
//
//	CONVOS_TEST_IRC_SERVER=irc://localhost:6667?tls=0   # plain-text ergochat
//	CONVOS_TEST_IRC_SERVER=irc://localhost:6697          # TLS with insecure verify
const ircIntegrationEnv = "CONVOS_TEST_IRC_SERVER"

// ircEventTimeout is how long to wait for a single expected IRC event.
const ircEventTimeout = 15 * time.Second

// IRC event type constants used in predicate closures.
const (
	evState   = "state"
	evMessage = "message"
	evSent    = "sent"

	typeConnection = "connection"
	typeFrozen     = "frozen"
	typeJoin       = "join"
	typePart       = "part"
	typeQuit       = "quit"
	typeNickChange = "nick_change"
	typePrivate    = "private"
)

// waitForEvent reads from sub, discarding events that don't match pred, until
// one matches or ircEventTimeout elapses. On timeout the test is failed immediately.
func waitForEvent(t *testing.T, sub *core.Subscription, pred func(map[string]any) bool) map[string]any {
	t.Helper()
	deadline := time.After(ircEventTimeout)
	for {
		select {
		case ev, ok := <-sub.Events():
			if !ok {
				t.Fatal("subscription channel closed unexpectedly")
				return nil
			}
			m, ok := ev.(map[string]any)
			if !ok {
				continue
			}
			if pred(m) {
				return m
			}
		case <-deadline:
			t.Fatal("timed out waiting for expected IRC event")
			return nil
		}
	}
}

// waitConnected blocks until a "connected" state event arrives on sub.
func waitConnected(t *testing.T, sub *core.Subscription) {
	t.Helper()
	waitForEvent(t, sub, func(m map[string]any) bool {
		return m["event"] == evState &&
			m["type"] == typeConnection &&
			m["state"] == string(core.StateConnected)
	})
}

// connectTestIRC creates a fresh Connection for nick, connects to serverURL,
// waits for the connected-state event, and registers t.Cleanup to disconnect.
//
// The nick is injected as the "nick" query param of the server URL. All other
// URL params (e.g. tls=0) are preserved.
func connectTestIRC(t *testing.T, serverURL, nick string) (*Connection, *core.Subscription) {
	t.Helper()

	u, err := url.Parse(serverURL)
	if err != nil {
		t.Fatalf("connectTestIRC: bad server URL %q: %v", serverURL, err)
	}
	q := u.Query()
	q.Set("nick", nick)
	u.RawQuery = q.Encode()

	c := test.NewTestCore()
	user := core.NewUser(nick+"@convos.test", c)
	conn := NewConnection(u.String(), user)
	sub := c.Events().SubscribeUser(user.ID())

	// Register cleanup before Connect so it always runs even if Connect fails.
	t.Cleanup(func() {
		sub.Close()
		_ = conn.Disconnect()
	})

	if err := conn.Connect(); err != nil {
		t.Fatalf("Connect(%q): %v", u, err)
	}
	waitConnected(t, sub)

	return conn, sub
}

// joinChannel sends /join and waits for the frozen (join-confirmed) event on sub.
func joinChannel(t *testing.T, conn *Connection, sub *core.Subscription, channel string) {
	t.Helper()
	if err := conn.Send(channel, "/join "+channel); err != nil {
		t.Fatalf("joinChannel %q: %v", channel, err)
	}
	waitForEvent(t, sub, func(m map[string]any) bool {
		return m["event"] == evState &&
			m["type"] == typeFrozen &&
			m["conversation_id"] == strings.ToLower(channel)
	})
}

// randSuffix returns a random 5-digit string for unique test nick / channel names.
// math/rand is intentionally used here; cryptographic strength is not required.
func randSuffix() string {
	return fmt.Sprintf("%05d", rand.IntN(100000)) //nolint:gosec
}

// TestIRCIntegration is a comprehensive end-to-end test suite for the IRC backend.
// It requires a live ergochat (or compatible) server and is skipped unless
// CONVOS_TEST_IRC_SERVER is set.
//
// Example:
//
//	CONVOS_TEST_IRC_SERVER=irc://localhost:6667?tls=0 go test -v -run TestIRCIntegration ./pkg/irc/
func TestIRCIntegration(t *testing.T) {
	t.Parallel()

	serverURL := os.Getenv(ircIntegrationEnv)
	if serverURL == "" {
		t.Skipf("%s not set; skipping IRC integration tests", ircIntegrationEnv)
	}

	// ──────────────────────────────────────────────────────────────
	// 1. Connection lifecycle – state transitions and server info
	// ──────────────────────────────────────────────────────────────
	t.Run("connect_state_and_nick", func(t *testing.T) {
		t.Parallel()
		nick := "cvt" + randSuffix()
		conn, _ := connectTestIRC(t, serverURL, nick)

		if conn.State() != core.StateConnected {
			t.Errorf("State = %q after connect, want %q", conn.State(), core.StateConnected)
		}

		// The server may append "_" if the nick is already taken; the nick must
		// still start with our requested prefix.
		if got := conn.Nick(); !strings.HasPrefix(got, "cvt") {
			t.Errorf("Nick = %q; expected it to start with %q", got, "cvt")
		}

		// RPL_WELCOME sets the "server" info field.
		if info := conn.Info(); info["server"] == nil || info["server"] == "" {
			t.Errorf("Expected non-empty server info after connect, got: %v", info)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 2. Channel join – conversation is created and unfrozen
	// ──────────────────────────────────────────────────────────────
	t.Run("join_channel", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		nick := "cvt" + sfx
		channel := "#cvtest" + sfx

		conn, sub := connectTestIRC(t, serverURL, nick)
		joinChannel(t, conn, sub, channel)

		conv := conn.GetConversation(strings.ToLower(channel))
		if conv == nil {
			t.Fatalf("Conversation %q not created after JOIN", channel)
		}
		if conv.Frozen() != "" {
			t.Errorf("Conversation.Frozen = %q after JOIN, want empty", conv.Frozen())
		}

		// Self must appear in the participant list (populated by RPL_NAMREPLY).
		found := false
		for p := range conv.Participants() {
			if strings.EqualFold(p, nick) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Self nick %q not in participants after JOIN: %v", nick, conv.Participants())
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 3. Channel message – B's message is received by A and persisted
	// ──────────────────────────────────────────────────────────────
	t.Run("channel_message", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, subB := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)
		joinChannel(t, connB, subB, channel)

		// Wait until A can observe B's JOIN so we know both are in the channel.
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// B sends a message to the channel; A must receive it.
		wantMsg := "hello from B id=" + sfx
		if err := connB.Send(channel, wantMsg); err != nil {
			t.Fatalf("B.Send: %v", err)
		}

		ev := waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evMessage &&
				m["conversation_id"] == strings.ToLower(channel) &&
				m["message"] == wantMsg
		})
		if from := fmt.Sprintf("%v", ev["from"]); !strings.EqualFold(from, nickB) {
			t.Errorf("message from = %q, want %q", from, nickB)
		}

		// Message must also be persisted to the backend.
		convA := connA.GetConversation(strings.ToLower(channel))
		if convA == nil {
			t.Fatal("A: channel conversation missing from connection")
		}
		result, err := connA.User().Core().Backend().LoadMessages(convA, core.MessageQuery{Limit: 50})
		if err != nil {
			t.Fatalf("LoadMessages: %v", err)
		}
		found := false
		for _, msg := range result.Messages {
			if msg.Message == wantMsg {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Message %q not found in persisted messages; got: %v", wantMsg, result.Messages)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 4. Private message – A sends PM to B; B receives it
	// ──────────────────────────────────────────────────────────────
	t.Run("private_message", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, _ := connectTestIRC(t, serverURL, nickA)
		_, subB := connectTestIRC(t, serverURL, nickB)

		wantMsg := "private hello id=" + sfx
		if err := connA.Send(nickB, wantMsg); err != nil {
			t.Fatalf("A.Send PM: %v", err)
		}

		ev := waitForEvent(t, subB, func(m map[string]any) bool {
			return m["event"] == evMessage &&
				m["type"] == typePrivate &&
				m["message"] == wantMsg
		})
		if from := fmt.Sprintf("%v", ev["from"]); !strings.EqualFold(from, nickA) {
			t.Errorf("PM from = %q, want %q", from, nickA)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 5. Nick change – B changes nick; A sees nick_change; participant lists updated
	// ──────────────────────────────────────────────────────────────
	t.Run("nick_change", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx
		newNickB := "cvtBx" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, subB := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)

		// B joins so they share a channel with A (required for NICK propagation).
		if err := connB.Send(channel, "/join "+channel); err != nil {
			t.Fatalf("B /join: %v", err)
		}
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// B changes nick.
		if err := connB.Send("", "/nick "+newNickB); err != nil {
			t.Fatalf("B /nick: %v", err)
		}

		// A must receive a nick_change event for B.
		ev := waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeNickChange &&
				strings.EqualFold(fmt.Sprintf("%v", m["old_nick"]), nickB)
		})
		if newNick := fmt.Sprintf("%v", ev["new_nick"]); !strings.EqualFold(newNick, newNickB) {
			t.Errorf("nick_change new_nick = %q, want %q", newNick, newNickB)
		}

		// Wait for B to process its own NICK message before reading connB.Nick().
		// A's event and B's callback run in separate goroutines; without this
		// wait there is a race between the assertion and B updating c.nick.
		waitForEvent(t, subB, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeNickChange &&
				strings.EqualFold(fmt.Sprintf("%v", m["old_nick"]), nickB)
		})

		// B's own Nick() must reflect the change.
		if got := connB.Nick(); !strings.EqualFold(got, newNickB) {
			t.Errorf("B.Nick() = %q after change, want %q", got, newNickB)
		}

		// A's participant list for the channel must show the new nick only.
		convA := connA.GetConversation(strings.ToLower(channel))
		if convA != nil {
			ps := convA.Participants()
			foundNew, foundOld := false, false
			for p := range ps {
				if strings.EqualFold(p, newNickB) {
					foundNew = true
				}
				if strings.EqualFold(p, nickB) {
					foundOld = true
				}
			}
			if !foundNew {
				t.Errorf("New nick %q not in A's participant list: %v", newNickB, ps)
			}
			if foundOld {
				t.Errorf("Old nick %q still in A's participant list", nickB)
			}
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 6. Quit – B disconnects; A sees quit event; B removed from participants
	// ──────────────────────────────────────────────────────────────
	t.Run("quit", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, _ := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)
		if err := connB.Send(channel, "/join "+channel); err != nil {
			t.Fatalf("B /join: %v", err)
		}
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// B disconnects (sends QUIT to server).
		if err := connB.Disconnect(); err != nil {
			t.Fatalf("B.Disconnect: %v", err)
		}

		// A must receive a quit event for B.
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeQuit &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// B must no longer appear in A's participant list.
		if convA := connA.GetConversation(strings.ToLower(channel)); convA != nil {
			for p := range convA.Participants() {
				if strings.EqualFold(p, nickB) {
					t.Errorf("B's nick %q still in participant list after quit", nickB)
					break
				}
			}
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 7. Kick – A (channel creator / op) kicks B; both sides see the event
	//
	// On ergochat the first user to join a channel becomes channel operator.
	// ──────────────────────────────────────────────────────────────
	t.Run("kick", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx // joins first → gets channel op
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, subB := connectTestIRC(t, serverURL, nickB)

		// A joins first to obtain operator status.
		joinChannel(t, connA, subA, channel)

		joinChannel(t, connB, subB, channel)
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// A kicks B.
		if err := connA.Send(channel, "/kick "+nickB+" integration test"); err != nil {
			t.Fatalf("A /kick: %v", err)
		}

		// A must receive a part event with kicker set.
		ev := waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typePart &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB) &&
				m["kicker"] != nil
		})
		if kicker := fmt.Sprintf("%v", ev["kicker"]); !strings.EqualFold(kicker, nickA) {
			t.Errorf("kick event kicker = %q, want %q", kicker, nickA)
		}

		// B must also receive a part event (for itself being kicked).
		waitForEvent(t, subB, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typePart &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// B's conversation must be removed after being kicked.
		if connB.GetConversation(strings.ToLower(channel)) != nil {
			t.Error("B: channel conversation should be removed after kick")
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 8. Part – leave a channel; conversation is removed
	// ──────────────────────────────────────────────────────────────
	t.Run("part", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nick := "cvt" + sfx

		conn, sub := connectTestIRC(t, serverURL, nick)
		joinChannel(t, conn, sub, channel)

		if conn.GetConversation(strings.ToLower(channel)) == nil {
			t.Fatalf("Conversation %q missing after JOIN", channel)
		}

		if err := conn.Send(channel, "/part "+channel); err != nil {
			t.Fatalf("/part: %v", err)
		}

		waitForEvent(t, sub, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typePart &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nick) &&
				m["conversation_id"] == strings.ToLower(channel)
		})

		if conn.GetConversation(strings.ToLower(channel)) != nil {
			t.Error("Conversation should be removed after PART")
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 9. Topic – set a channel topic; event and Conversation.Topic() updated
	// ──────────────────────────────────────────────────────────────
	t.Run("topic", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nick := "cvt" + sfx

		conn, sub := connectTestIRC(t, serverURL, nick)
		joinChannel(t, conn, sub, channel)

		wantTopic := "integration test topic " + sfx
		if err := conn.Send(channel, "/topic "+wantTopic); err != nil {
			t.Fatalf("/topic: %v", err)
		}

		waitForEvent(t, sub, func(m map[string]any) bool {
			return m["event"] == evState &&
				m["type"] == typeFrozen &&
				m["conversation_id"] == strings.ToLower(channel) &&
				m["topic"] == wantTopic
		})

		conv := conn.GetConversation(strings.ToLower(channel))
		if conv == nil {
			t.Fatal("channel conversation missing after topic change")
		}
		if conv.Topic() != wantTopic {
			t.Errorf("Conversation.Topic() = %q, want %q", conv.Topic(), wantTopic)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 10. WHOIS – query own nick; reply event carries user info
	// ──────────────────────────────────────────────────────────────
	t.Run("whois", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		nick := "cvt" + sfx

		conn, sub := connectTestIRC(t, serverURL, nick)

		// Use the actual nick the server assigned (may differ if nick was taken).
		actualNick := conn.Nick()
		if err := conn.Send("", "/whois "+actualNick); err != nil {
			t.Fatalf("/whois: %v", err)
		}

		ev := waitForEvent(t, sub, func(m map[string]any) bool {
			return m["event"] == evSent && m["message"] == "/whois"
		})
		if ev["nick"] == nil {
			t.Errorf("whois reply missing 'nick' field; got: %v", ev)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 11. NAMES – request member list; both nicks appear in the reply
	// ──────────────────────────────────────────────────────────────
	t.Run("names", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, _ := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)
		if err := connB.Send(channel, "/join "+channel); err != nil {
			t.Fatalf("B /join: %v", err)
		}
		// Wait for A to confirm B has joined before requesting NAMES.
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// Send /names with the channel as the target so it resolves to the right channel.
		if err := connA.Send(channel, "/names"); err != nil {
			t.Fatalf("/names: %v", err)
		}

		ev := waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evSent &&
				m["conversation_id"] == strings.ToLower(channel)
		})

		participants, _ := ev["participants"].([]map[string]any)
		if len(participants) < 2 {
			t.Errorf("NAMES reply has %d participant(s), want ≥2", len(participants))
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 12. IRCv3 caps – multi-prefix, userhost-in-names, extended-join
	//     are all acknowledged by ergo after CAP negotiation.
	// ──────────────────────────────────────────────────────────────
	t.Run("ircv3_caps_negotiated", func(t *testing.T) {
		t.Parallel()
		conn, _ := connectTestIRC(t, serverURL, "cvt"+randSuffix())

		caps, _ := conn.Info()["capabilities"].([]string)
		capSet := make(map[string]bool, len(caps))
		for _, c := range caps {
			capSet[c] = true
		}
		for _, want := range []string{"multi-prefix", "userhost-in-names", "extended-join"} {
			if !capSet[want] {
				t.Errorf("cap %q not in acknowledged caps: %v", want, caps)
			}
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 13. userhost-in-names – NAMES participants carry a host field
	// ──────────────────────────────────────────────────────────────
	t.Run("ircv3_userhost_in_names", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		conn, sub := connectTestIRC(t, serverURL, "cvt"+sfx)
		joinChannel(t, conn, sub, "#cvtest"+sfx)

		conv := conn.GetConversation("#cvtest" + sfx)
		if conv == nil {
			t.Fatal("conversation missing after join")
		}
		for nick, p := range conv.Participants() {
			if host, _ := p["host"].(string); host == "" {
				t.Errorf("participant %q missing host field (userhost-in-names): %v", nick, p)
			}
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 14. multi-prefix – channel creator's op mode appears in NAMES data
	// ──────────────────────────────────────────────────────────────
	t.Run("ircv3_multi_prefix", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		conn, sub := connectTestIRC(t, serverURL, "cvt"+sfx)
		joinChannel(t, conn, sub, "#cvtest"+sfx)

		conv := conn.GetConversation("#cvtest" + sfx)
		if conv == nil {
			t.Fatal("conversation missing after join")
		}
		// ergo grants op to the first joiner; parseNickMode must translate "@" → "o".
		actualNick := conn.Nick()
		p, ok := conv.Participants()[strings.ToLower(actualNick)]
		if !ok {
			t.Fatalf("self nick %q not in participants: %v", actualNick, conv.Participants())
		}
		if mode, _ := p["mode"].(string); !strings.Contains(mode, "o") {
			t.Errorf("participant mode = %q, want it to contain 'o' (channel op)", mode)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 15. extended-join – joining user's realname is stored in participant data
	// ──────────────────────────────────────────────────────────────
	t.Run("ircv3_extended_join", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, _ := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)
		if err := connB.Send(channel, "/join "+channel); err != nil {
			t.Fatalf("B /join: %v", err)
		}
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		convA := connA.GetConversation(strings.ToLower(channel))
		if convA == nil {
			t.Fatal("A: channel conversation missing")
		}
		var bEntry map[string]any
		for n, p := range convA.Participants() {
			if strings.EqualFold(n, nickB) {
				bEntry = p
				break
			}
		}
		if bEntry == nil {
			t.Fatalf("B's nick %q not in A's participants: %v", nickB, convA.Participants())
		}
		if _, ok := bEntry["realname"]; !ok {
			t.Errorf("B's participant entry missing 'realname' (extended-join not working): %v", bEntry)
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 16. Disconnect – state becomes disconnected; conversations are frozen
	// ──────────────────────────────────────────────────────────────
	t.Run("disconnect", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nick := "cvt" + sfx

		conn, sub := connectTestIRC(t, serverURL, nick)
		joinChannel(t, conn, sub, channel)

		if err := conn.Disconnect(); err != nil {
			t.Fatalf("Disconnect: %v", err)
		}

		if conn.State() != core.StateDisconnected {
			t.Errorf("State = %q after Disconnect, want %q", conn.State(), core.StateDisconnected)
		}

		// The disconnect callback freezes all open conversations. Give it a moment.
		time.Sleep(100 * time.Millisecond)
		conv := conn.GetConversation(strings.ToLower(channel))
		if conv != nil && conv.Frozen() == "" {
			t.Error("Channel conversation should be frozen after disconnect")
		}
	})

	// ──────────────────────────────────────────────────────────────
	// 17. TAGMSG - Typing indicators and reactions
	// ──────────────────────────────────────────────────────────────
	t.Run("ircv3_tagmsg", func(t *testing.T) {
		t.Parallel()
		sfx := randSuffix()
		channel := "#cvtest" + sfx
		nickA := "cvtA" + sfx
		nickB := "cvtB" + sfx

		connA, subA := connectTestIRC(t, serverURL, nickA)
		connB, subB := connectTestIRC(t, serverURL, nickB)

		joinChannel(t, connA, subA, channel)
		if err := connB.Send(channel, "/join "+channel); err != nil {
			t.Fatalf("B /join: %v", err)
		}
		// Wait for A to see B join
		waitForEvent(t, subA, func(m map[string]any) bool {
			return m["event"] == evState && m["type"] == typeJoin &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickB)
		})

		// 1. Typing notification
		// A sends typing notification to channel
		// Note: We use the underlying client to send TAGMSG as it's not a user command
		if err := connA.client.SendWithTags(map[string]string{"+typing": "active"}, "TAGMSG", channel); err != nil {
			t.Fatalf("A SendWithTags: %v", err)
		}

		// B should receive the typing event
		ev := waitForEvent(t, subB, func(m map[string]any) bool {
			return m["event"] == evState &&
				m["type"] == "typing" &&
				m["conversation_id"] == strings.ToLower(channel) &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickA)
		})
		if typing := fmt.Sprintf("%v", ev["typing"]); typing != "active" {
			t.Errorf("typing status = %q, want active", typing)
		}

		// 2. Reaction
		// A sends a reaction to a hypothetical message
		if err := connA.client.SendWithTags(map[string]string{
			"+draft/reply": "msg123",
			"+draft/react": "👍",
		}, "TAGMSG", channel); err != nil {
			t.Fatalf("A SendWithTags: %v", err)
		}

		// B should receive the reaction event
		ev = waitForEvent(t, subB, func(m map[string]any) bool {
			return m["event"] == evMessage &&
				m["type"] == "reaction" &&
				m["conversation_id"] == strings.ToLower(channel) &&
				strings.EqualFold(fmt.Sprintf("%v", m["nick"]), nickA)
		})
		if msg := fmt.Sprintf("%v", ev["message"]); msg != "👍" {
			t.Errorf("reaction emoji = %q, want 👍", msg)
		}
		if replyTo := fmt.Sprintf("%v", ev["reply_to"]); replyTo != "msg123" {
			t.Errorf("reaction reply_to = %q, want msg123", replyTo)
		}
	})
}
