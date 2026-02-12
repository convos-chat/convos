package irc

import (
	"fmt"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/ergochat/irc-go/ircevent"
	"github.com/ergochat/irc-go/ircmsg"
)

// handleMessage handles incoming PRIVMSG and NOTICE messages.
func (c *Connection) handleMessage(msg ircmsg.Message, msgType string) {
	if len(msg.Params) < 2 {
		return
	}

	target := msg.Params[0]
	message := msg.Params[1]
	nick := msg.Nick()

	// Handle CTCP requests
	if msgType == "private" && strings.HasPrefix(message, "\x01") && strings.HasSuffix(message, "\x01") {
		ctcp := message[1 : len(message)-1]
		if strings.HasPrefix(ctcp, "ACTION ") {
			msgType = "action"
			message = ctcp[7:]
		} else {
			c.handleCTCP(nick, ctcp)
			return
		}
	}

	// Determine conversation target
	convID := target
	if target == "*" {
		convID = ""
	} else if target == c.Nick() {
		// Private message - use sender's nick as conversation ID
		convID = nick
	}

	// Get or create conversation
	conv := c.GetConversation(convID)
	if conv == nil {
		if convID == "" {
			conv = core.NewConversationWithID("", c.Name(), c)
		} else {
			conv = core.NewConversation(convID, c)
		}
		c.AddConversation(conv)
	}

	if conv.Frozen() != "" {
		conv.SetFrozen("")
		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "frozen",
			"conversation_id": conv.ID(),
			"frozen":          "",
		})
	}

	// Check for highlight
	highlight := c.isHighlight(message)

	c.emitEvent(map[string]any{
		"event":           "message",
		"conversation_id": conv.ID(),
		"from":            nick,
		"highlight":       highlight,
		"message":         message,
		"type":            msgType,
	})

	c.persistMessage(conv.ID(), nick, message, msgType, highlight)

	if highlight {
		c.persistNotification(conv.ID(), nick, message, msgType)
	}
}

// handleCTCP responds to CTCP queries (PING, VERSION, TIME).
func (c *Connection) handleCTCP(nick, ctcp string) {
	parts := strings.SplitN(ctcp, " ", 2)
	command := strings.ToUpper(parts[0])

	var reply string
	switch command {
	case "PING":
		// Echo back the same payload
		reply = ctcp
	case "VERSION":
		reply = "VERSION Convos (https://convos.chat)"
	case "TIME":
		reply = "TIME " + time.Now().UTC().Format(time.RFC1123)
	default:
		return
	}

	if err := c.client.Send("NOTICE", nick, "\x01"+reply+"\x01"); err != nil {
		slog.Error("Failed to send CTCP reply", "nick", nick, "ctcp", ctcp, "error", err)
	}
}

// handleJoin handles JOIN messages.
func (c *Connection) handleJoin(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	channel := msg.Params[0]
	nick := msg.Nick()

	if nick == c.Nick() {
		// We joined - create/get conversation and emit frozen event
		conv := c.GetConversation(channel)
		if conv == nil {
			conv = core.NewConversation(channel, c)
			c.AddConversation(conv)
		}

		conv.SetFrozen("")
		conv.AddParticipant(nick, map[string]any{
			"nick": nick,
			"mode": "",
		})

		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "frozen",
			"conversation_id": conv.ID(),
			"frozen":          conv.Frozen(),
			"name":            conv.Name(),
			"topic":           conv.Topic(),
			"unread":          conv.Unread(),
		})
		c.saveState()
	} else {
		// Someone else joined
		conv := c.GetConversation(channel)
		if conv == nil {
			conv = core.NewConversation(channel, c)
			c.AddConversation(conv)
		}
		conv.AddParticipant(nick, map[string]any{
			"nick": nick,
			"mode": "",
		})

		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "join",
			"conversation_id": strings.ToLower(channel),
			"nick":            nick,
		})
	}
}

// handlePart handles PART messages.
func (c *Connection) handlePart(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	channel := msg.Params[0]
	nick := msg.Nick()
	reason := ""
	if len(msg.Params) > 1 {
		reason = msg.Params[1]
	}

	if nick == c.Nick() {
		c.RemoveConversation(channel)
		c.saveState()
	} else {
		if conv := c.GetConversation(channel); conv != nil {
			conv.RemoveParticipant(nick)
		}
	}

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "part",
		"conversation_id": strings.ToLower(channel),
		"nick":            nick,
		"message":         reason,
	})
}

// handleQuit handles QUIT messages.
func (c *Connection) handleQuit(msg ircmsg.Message) {
	nick := msg.Nick()
	message := ""
	if len(msg.Params) > 0 {
		message = strings.Join(msg.Params, " ")
	}

	for _, conv := range c.Conversations() {
		conv.RemoveParticipant(nick)
	}

	c.emitEvent(map[string]any{
		"event":   "state",
		"type":    "quit",
		"nick":    nick,
		"message": message,
	})
}

// handleKick handles KICK messages.
// Format: :nick!user@host KICK #channel target :reason
func (c *Connection) handleKick(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	channel := msg.Params[0]
	target := msg.Params[1]
	kicker := msg.Nick()
	reason := ""
	if len(msg.Params) > 2 {
		reason = msg.Params[2]
	}

	kickMsg := fmt.Sprintf("%s was kicked by %s", target, kicker)
	if reason != "" {
		kickMsg += ": " + reason
	}

	if target == c.Nick() {
		// We were kicked - remove conversation and emit
		c.RemoveConversation(channel)
		c.saveState()
	} else {
		if conv := c.GetConversation(channel); conv != nil {
			conv.RemoveParticipant(target)
		}
	}

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "part",
		"conversation_id": strings.ToLower(channel),
		"nick":            target,
		"message":         kickMsg,
		"kicker":          kicker,
	})
}

// handleInvite handles INVITE messages.
// Format: :nick!user@host INVITE target #channel
func (c *Connection) handleInvite(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	inviter := msg.Nick()
	channel := msg.Params[1]

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "invite",
		"conversation_id": strings.ToLower(channel),
		"nick":            inviter,
		"message":         fmt.Sprintf("%s invited you to %s.", inviter, channel),
	})
}

// handleNick handles NICK change messages.
func (c *Connection) handleNick(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	oldNick := msg.Nick()
	newNick := msg.Params[0]

	if oldNick == c.Nick() {
		// Our nick changed
		c.mu.Lock()
		c.nick = newNick
		c.mu.Unlock()
		c.emitInfo()
	}

	for _, conv := range c.Conversations() {
		participants := conv.Participants()
		if info, ok := participants[oldNick]; ok {
			info["nick"] = newNick
			conv.AddParticipant(newNick, info)
			conv.RemoveParticipant(oldNick)
		}
	}

	c.emitEvent(map[string]any{
		"event":    "state",
		"type":     "nick_change",
		"old_nick": oldNick,
		"new_nick": newNick,
	})
}

// handleNickInUse handles ERR_NICKNAMEINUSE (433) by appending "_" and retrying.
func (c *Connection) handleNickInUse(msg ircmsg.Message) {
	// msg.Params: [<current_nick>, <attempted_nick>, "Nickname is already in use"]
	attempted := ""
	if len(msg.Params) >= 2 {
		attempted = msg.Params[1]
	}
	if attempted == "" {
		attempted = c.Nick()
	}

	newNick := attempted + "_"
	c.emitEvent(map[string]any{
		"event":   "state",
		"type":    "connection",
		"state":   "connected",
		"message": fmt.Sprintf("Nick %s is in use, trying %s.", attempted, newNick),
	})

	if err := c.client.Send("NICK", newNick); err != nil {
		slog.Error("Failed to change nick after nickname in use", "attempted", newNick, "error", err)
	}
}

// handleTopic handles TOPIC messages (topic changed by a user).
func (c *Connection) handleTopic(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	channel := msg.Params[0]
	topic := msg.Params[1]

	conv := c.GetConversation(channel)
	if conv != nil {
		conv.SetTopic(topic)
	}

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "frozen",
		"conversation_id": strings.ToLower(channel),
		"topic":           topic,
	})
}

// handleTopicReply handles RPL_TOPIC (332) - topic on channel join.
func (c *Connection) handleTopicReply(msg ircmsg.Message) {
	if len(msg.Params) < 3 {
		return
	}

	channel := msg.Params[1]
	topic := msg.Params[2]

	conv := c.GetConversation(channel)
	if conv != nil {
		conv.SetTopic(topic)
		if conv.Frozen() != "" {
			conv.SetFrozen("")
		}
		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "frozen",
			"conversation_id": conv.ID(),
			"frozen":          conv.Frozen(),
			"name":            conv.Name(),
			"topic":           topic,
			"unread":          conv.Unread(),
		})
	}
}

// handleTopicWhoTime handles RPL_TOPICWHOTIME (333).
func (c *Connection) handleTopicWhoTime(msg ircmsg.Message) {
	if len(msg.Params) < 3 {
		return
	}
	// Params: <nick> <channel> <who> [<time>]
	channel := strings.ToLower(msg.Params[1])
	who := msg.Params[2]

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "frozen",
		"conversation_id": channel,
		"topic_by":        who,
	})
}

// handleMode handles MODE messages.
func (c *Connection) handleMode(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	target := msg.Params[0]
	modeStr := msg.Params[1]

	// User mode change (not a channel)
	if !core.ChannelRE.MatchString(target) {
		c.emitEvent(map[string]any{
			"event": "state",
			"type":  "info",
			"nick":  c.Nick(),
			"mode":  modeStr,
		})
		return
	}

	from := msg.Nick()
	convID := strings.ToLower(target)
	modeArgs := msg.Params[2:]

	// Parse mode string: separate user-targeted modes (o, v, h, etc.)
	// from channel modes (n, t, m, etc.)
	argIdx := 0
	add := true
	var channelModes []byte
	lastSign := byte(0)

	for i := 0; i < len(modeStr); i++ {
		ch := modeStr[i]
		if ch == '+' || ch == '-' {
			add = ch == '+'
			continue
		}

		if strings.ContainsRune(userModeChars, rune(ch)) && argIdx < len(modeArgs) {
			// User mode — emit with nick so the frontend updates participants
			targetNick := modeArgs[argIdx]
			argIdx++
			prefix := "+"
			if !add {
				prefix = "-"
			}
			c.emitEvent(map[string]any{
				"event":           "state",
				"type":            "mode",
				"conversation_id": convID,
				"from":            from,
				"nick":            targetNick,
				"mode":            prefix + string(ch),
			})
			continue
		}

		// Channel mode — accumulate into a single mode string
		sign := byte('+')
		if !add {
			sign = '-'
		}
		if sign != lastSign {
			channelModes = append(channelModes, sign)
			lastSign = sign
		}
		channelModes = append(channelModes, ch)

		// Consume parameter for modes that require one
		if (ch == 'k' || (ch == 'l' && add) || ch == 'b' || ch == 'e' || ch == 'I') && argIdx < len(modeArgs) {
			argIdx++
		}
	}

	// Emit channel mode changes
	if len(channelModes) > 0 {
		chanModeStr := string(channelModes)
		if conv := c.GetConversation(convID); conv != nil {
			conv.UpdateModes(chanModeStr)
		}
		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "mode",
			"conversation_id": convID,
			"from":            from,
			"mode":            chanModeStr,
			"mode_changed":    true,
		})
	}
}

// handleChannelModeIs handles RPL_CHANNELMODEIS (324) - response to a mode query.
// Format: :server 324 <nick> <channel> <modes> [<mode_params>...]
func (c *Connection) handleChannelModeIs(msg ircmsg.Message) {
	if len(msg.Params) < 3 {
		return
	}

	channel := msg.Params[1]
	mode := msg.Params[2]
	args := ""
	if len(msg.Params) > 3 {
		args = strings.Join(msg.Params[3:], " ")
	}

	convID := strings.ToLower(channel)
	if conv := c.GetConversation(convID); conv != nil {
		conv.UpdateModes(mode)
	}

	c.emitEvent(map[string]any{
		"event":           "state",
		"type":            "mode",
		"conversation_id": convID,
		"mode":            mode,
		"args":            args,
	})
}

// handleNamesReply handles RPL_NAMREPLY (353) - accumulates channel members.
// Format: :<server> 353 <nick> <type> <channel> :<nicks...>
func (c *Connection) handleNamesReply(msg ircmsg.Message) {
	if len(msg.Params) < 4 {
		return
	}

	channel := strings.ToLower(msg.Params[2])
	nicks := strings.Fields(msg.Params[3])

	c.mu.Lock()
	defer c.mu.Unlock()

	conv := c.GetConversation(channel)
	if conv == nil {
		conv = core.NewConversation(channel, c)
		c.AddConversation(conv)
	}

	if conv.Frozen() != "" {
		conv.SetFrozen("")
		c.emitEvent(map[string]any{
			"event":           "state",
			"type":            "frozen",
			"conversation_id": conv.ID(),
			"frozen":          "",
		})
	}

	for _, raw := range nicks {
		mode, nick := parseNickMode(raw)
		participant := map[string]any{
			"nick": nick,
			"mode": mode,
		}
		c.namesBuffer[channel] = append(c.namesBuffer[channel], participant)
		conv.AddParticipant(nick, participant)
	}
}

// handleEndOfNames handles RPL_ENDOFNAMES (366) - emits collected participant list.
// Format: :<server> 366 <nick> <channel> :End of /NAMES list
func (c *Connection) handleEndOfNames(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	channel := strings.ToLower(msg.Params[1])

	c.mu.Lock()
	participants := c.namesBuffer[channel]
	delete(c.namesBuffer, channel)
	c.mu.Unlock()

	if participants == nil {
		participants = []map[string]any{}
	}

	c.emitEvent(map[string]any{
		"event":           "sent",
		"conversation_id": channel,
		"message":         "/names",
		"command":         []string{"names"},
		"participants":    participants,
	})
}

// handleWhoisReply collects WHOIS response numerics into the buffer.
func (c *Connection) handleWhoisReply(code string, msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	nick := strings.ToLower(msg.Params[1])

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.whoisBuffer[nick] == nil {
		c.whoisBuffer[nick] = map[string]any{
			"nick":        msg.Params[1], // preserve original case
			"away":        "",
			"channels":    map[string]any{},
			"fingerprint": "",
			"host":        "",
			"idle_for":    0,
			"name":        "",
			"server":      "",
			"server_info": "",
			"user":        "",
		}
	}
	w := c.whoisBuffer[nick]

	switch code {
	case ircevent.RPL_WHOISUSER: // <nick> <user> <host> * :<realname>
		if len(msg.Params) >= 4 {
			w["user"] = msg.Params[2]
			w["host"] = msg.Params[3]
		}
		if len(msg.Params) >= 6 {
			w["name"] = msg.Params[5]
		}
	case ircevent.RPL_WHOISSERVER: // <nick> <server> :<server info>
		if len(msg.Params) >= 3 {
			w["server"] = msg.Params[2]
		}
		if len(msg.Params) >= 4 {
			w["server_info"] = msg.Params[3]
		}
	case ircevent.RPL_WHOISIDLE: // <nick> <idle_seconds> <signon> :seconds idle
		if len(msg.Params) >= 3 {
			var secs int
			if _, err := fmt.Sscanf(msg.Params[2], "%d", &secs); err == nil {
				w["idle_for"] = secs
			}
		}
	case ircevent.RPL_WHOISCHANNELS: // <nick> :<channels>
		if len(msg.Params) >= 3 {
			channels, ok := w["channels"].(map[string]any)
			if !ok {
				channels = make(map[string]any)
				w["channels"] = channels
			}
			for ch := range strings.FieldsSeq(msg.Params[2]) {
				mode, chName := parseNickMode(ch) // reuse - same prefix format
				channels[chName] = map[string]any{"mode": mode}
			}
		}
	case ircevent.RPL_WHOISCERTFP:
		if len(msg.Params) >= 3 {
			w["fingerprint"] = msg.Params[2]
		}
	case ircevent.RPL_AWAY: // <nick> :<away message>
		if len(msg.Params) >= 3 {
			w["away"] = msg.Params[2]
		}
	case ircevent.RPL_WHOISACCOUNT: // <nick> <account> :is logged in as
		if len(msg.Params) >= 3 {
			w["account"] = msg.Params[2]
		}
	case ircevent.RPL_WHOISSECURE:
		w["secure"] = true
	}
}

// handleEndOfWhois handles RPL_ENDOFWHOIS (318) - emits collected WHOIS data.
func (c *Connection) handleEndOfWhois(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	nick := strings.ToLower(msg.Params[1])

	c.mu.Lock()
	whois := c.whoisBuffer[nick]
	delete(c.whoisBuffer, nick)
	c.mu.Unlock()

	if whois == nil {
		whois = map[string]any{"nick": msg.Params[1]}
	}

	whois["event"] = "sent"
	whois["message"] = "/whois"
	whois["command"] = []string{"whois"}
	c.emitEvent(whois)
}

// handleListReply handles RPL_LIST (322) — accumulates channel entries.
// Format: :server 322 nick #channel n_users :topic
func (c *Connection) handleListReply(msg ircmsg.Message) {
	if len(msg.Params) < 4 {
		return
	}

	name := msg.Params[1]
	nUsers, _ := strconv.Atoi(msg.Params[2])
	topic := msg.Params[3]

	// Strip mode prefix from topic (e.g., "[+nt] actual topic" → "actual topic")
	topic = regexp.MustCompile(`^\[\+[a-z]+\]\s?`).ReplaceAllString(topic, "")

	c.mu.Lock()
	if c.listBuf.conversations == nil {
		c.listBuf.conversations = make(map[string]listEntry)
	}
	c.listBuf.conversations[name] = listEntry{
		Name:           name,
		ConversationID: strings.ToLower(name),
		NUsers:         nUsers,
		Topic:          topic,
	}
	c.mu.Unlock()
}

// handleListEnd handles RPL_LISTEND (323) — marks LIST results as complete.
func (c *Connection) handleListEnd() {
	c.mu.Lock()
	c.listBuf.done = true
	c.mu.Unlock()
}

// handleNotice handles server numerics that should be displayed as notices.
func (c *Connection) handleNotice(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}
	message := msg.Params[len(msg.Params)-1]
	convID := ""

	// Ensure server conversation exists (empty ID matches Perl behavior)
	conv := c.GetConversation(convID)
	if conv == nil {
		conv = core.NewConversationWithID("", c.Name(), c)
		c.AddConversation(conv)
	}

	c.emitEvent(map[string]any{
		"event":           "message",
		"conversation_id": convID,
		"from":            msg.Source,
		"message":         message,
		"type":            "notice",
	})

	c.persistMessage(convID, msg.Source, message, "notice", false)
}

// handleErrorReply handles IRC error numerics (4xx) and surfaces them to the
// user. It tries to route the error to the relevant conversation when possible.
// Format: :server 482 yournick #channel :You're not channel operator
func (c *Connection) handleErrorReply(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	message := msg.Params[len(msg.Params)-1]

	convID := ""
	if len(msg.Params) >= 3 {
		candidate := strings.ToLower(msg.Params[1])
		if core.ChannelRE.MatchString(candidate) && c.GetConversation(candidate) != nil {
			convID = candidate
		}
	}

	c.emitEvent(map[string]any{
		"event":           "message",
		"conversation_id": convID,
		"from":            msg.Source,
		"message":         message,
		"type":            "error",
	})

	c.persistMessage(convID, msg.Source, message, "error", false)
}

// handleWelcome handles RPL_WELCOME (001).
func (c *Connection) handleWelcome(msg ircmsg.Message) {
	c.SetInfo("server", msg.Source)
	c.emitInfo()
	c.handleNotice(msg)
}

// handleISupport handles RPL_ISUPPORT (005).
func (c *Connection) handleISupport(msg ircmsg.Message) {
	// FIXME: Simple implementation: just store them in info for now
	for i := 1; i < len(msg.Params)-1; i++ {
		parts := strings.SplitN(msg.Params[i], "=", 2)
		key := strings.ToLower(parts[0])
		if len(parts) == 2 {
			c.SetInfo(key, parts[1])
		} else {
			c.SetInfo(key, true)
		}
	}
	c.emitInfo()
}

// parseNickMode extracts the mode prefix and nick from an IRC NAMES entry.
// Mode prefixes: ~ = q (founder), & = a (admin), @ = o (operator),
// % = h (half-op), + = v (voice).
func parseNickMode(raw string) (string, string) {
	if len(raw) == 0 {
		return "", ""
	}
	switch raw[0] {
	case '~':
		return "q", raw[1:]
	case '&':
		return "a", raw[1:]
	case '@':
		return "o", raw[1:]
	case '%':
		return "h", raw[1:]
	case '+':
		return "v", raw[1:]
	default:
		return "", raw
	}
}
