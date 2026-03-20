package irc

import (
	"fmt"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/version"
	"github.com/ergochat/irc-go/ircevent"
	"github.com/ergochat/irc-go/ircmsg"
)

// handleMessage handles incoming PRIVMSG and NOTICE messages.
func (c *Connection) handleMessage(msg ircmsg.Message, msgType core.MessageType) {
	if len(msg.Params) < 2 {
		return
	}

	target := msg.Params[0]
	message := msg.Params[1]
	nick := msg.Nick()
	ts := serverTimeOrNow(msg)
	tsRFC3339 := serverTimeOrNowRFC3339(msg)

	// Handle CTCP requests
	if msgType == core.MessageTypePrivate && strings.HasPrefix(message, "\x01") && strings.HasSuffix(message, "\x01") {
		ctcp := message[1 : len(message)-1]
		if strings.HasPrefix(ctcp, "ACTION ") {
			msgType = core.MessageTypeAction
			message = ctcp[7:]
		} else {
			c.handleCTCP(nick, ctcp)
			return
		}
	}

	conv := c.EnsureConversation(target, nick)

	if conv.Frozen() != "" {
		conv.SetFrozen("")
		c.emitEvent(&core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: ""})
	}

	isDM := target == c.Nick()
	highlight := c.isHighlight(message)

	// Extract IRCv3 message tags.
	_, msgID := msg.GetTag("msgid")
	_, account := msg.GetTag("account")
	replyTo := ""
	if _, v := msg.GetTag("+draft/reply"); v != "" {
		replyTo = v
	} else if _, v := msg.GetTag("reply"); v != "" {
		replyTo = v
	}

	event := &core.MessageEvent{
				ConversationID: conv.ID(),
		From:           nick,
		Message:        message,
		Type:           msgType,
		Highlight:      highlight,
		MsgID:          msgID,
		Account:        account,
		ReplyTo:        replyTo,
	}
	event.TS = tsRFC3339 // Use server time instead of auto-generated timestamp
	c.emitEvent(event)

	c.persistMessage(conv.ID(), nick, message, msgType, highlight, ts, msgID, account, replyTo)

	if nick != c.Nick() && highlight || isDM {
		c.persistNotification(conv.ID(), nick, message, msgType, ts)
	}

	if nick != c.Nick() && (msgType == core.MessageTypePrivate || msgType == core.MessageTypeAction) {
		conv.IncUnread()
		if highlight || isDM {
			conv.IncNotifications()
		}
		c.saveState()
	}
}

// handleTagMsg handles TAGMSG messages (typing indicators, reactions).
func (c *Connection) handleTagMsg(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	target := msg.Params[0]
	nick := msg.Nick()

	conv := c.EnsureConversation(target, nick)

	// +typing tag: emit state event
	if present, value := msg.GetTag("+typing"); present {
		c.emitEvent(&core.StateTypingEvent{Nick: nick, ConversationID: conv.ID(), Typing: value})
	}

	// +draft/react or react tag: emit reaction event
	reactEmoji := ""
	if present, value := msg.GetTag("+draft/react"); present {
		reactEmoji = value
	} else if present, value := msg.GetTag("react"); present {
		reactEmoji = value
	}

	if reactEmoji != "" {
		targetMsgID := ""
		if present, value := msg.GetTag("+draft/reply"); present {
			targetMsgID = value
		} else if present, value := msg.GetTag("reply"); present {
			targetMsgID = value
		}

		if targetMsgID != "" {
			event := &core.MessageEvent{ConversationID: conv.ID(), From: nick, Message: reactEmoji, Type: core.MessageTypeReaction, Highlight: false}
			event.TS = serverTimeOrNowRFC3339(msg)
			event.ReplyTo = targetMsgID
			c.emitEvent(event)
		}
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
		reply = fmt.Sprintf("VERSION Convos %s (https://convos.chat)", version.Version)
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

	// extended-join: params[1] = account ("*" if not logged in), params[2] = realname
	p := core.Participant{Nick: nick, Mode: ""}
	if len(msg.Params) >= 3 {
		if account := msg.Params[1]; account != "*" {
			p.Account = account
		}
		if realname := msg.Params[2]; realname != "" {
			p.Realname = realname
		}
	}

	if nick == c.Nick() {
		// We joined - create/get conversation and emit frozen event
		conv := c.GetConversation(channel)
		if conv == nil {
			conv = core.NewConversation(channel, c)
			c.AddConversation(conv)
		}

		conv.SetFrozen("")
		conv.AddParticipant(p)

		event := &core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: conv.Frozen(), Name: conv.Name(), Topic: conv.Topic(), Unread: conv.Unread()}
		c.emitEvent(event)
		c.saveState()
	} else {
		// Someone else joined
		conv := c.GetConversation(channel)
		if conv == nil {
			conv = core.NewConversation(channel, c)
			c.AddConversation(conv)
		}
		conv.AddParticipant(p)

		c.emitEvent(&core.StateJoinEvent{ConversationID: strings.ToLower(channel), Nick: nick, Account: p.Account})
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

	c.emitEvent(&core.StatePartEvent{ConversationID: strings.ToLower(channel), Nick: nick, Message: reason})
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

	c.emitEvent(&core.StateQuitEvent{Nick: nick, Message: message})
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

	c.emitEvent(&core.StatePartEvent{ConversationID: strings.ToLower(channel), Nick: target, Message: kickMsg, Kicker: kicker})
}

// handleInvite handles INVITE messages.
// Format: :nick!user@host INVITE target #channel
func (c *Connection) handleInvite(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	inviter := msg.Nick()
	channel := msg.Params[1]
	message := fmt.Sprintf("%s invited you to %s.", inviter, channel)

	c.emitEvent(&core.StateInviteEvent{ConversationID: strings.ToLower(channel), Nick: inviter, Message: message})
}

// handleNick handles NICK change messages.
func (c *Connection) handleNick(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	oldNick := msg.Nick()
	newNick := msg.Params[0]

	if oldNick == c.Nick() {
		// Our nick changed – clear any pending auto-fix sequence.
		c.mu.Lock()
		c.nick = newNick
		c.nickFixBase = ""
		c.mu.Unlock()
		c.emitInfo()
	}

	for _, conv := range c.Conversations() {
		participants := conv.Participants()
		if p, ok := participants[oldNick]; ok {
			p.Nick = newNick
			conv.AddParticipant(p)
			conv.RemoveParticipant(oldNick)
		}
	}

	c.emitEvent(&core.StateNickChangeEvent{OldNick: oldNick, NewNick: newNick})
}

// handleNickInUse handles ERR_NICKNAMEINUSE (433).
//
// Three cases are distinguished:
//  1. Pre-registration (c.nick == ""): the library's default handler was
//     cleared in the connect callback, so this is our reconnect path.
//     Retry by appending "_" to the attempted nick.
//  2. Auto-fix in progress (nickFixBase != "" and the 433 is for our fix
//     attempt): extend the fix by appending another "_".
//  3. Post-registration, user-initiated /nick: just surface the error.
func (c *Connection) handleNickInUse(msg ircmsg.Message) {
	// msg.Params: [<current_nick>, <attempted_nick>, "Nickname is already in use"]
	attempted := ""
	if len(msg.Params) >= 2 {
		attempted = msg.Params[1]
	}
	if attempted == "" {
		attempted = c.Nick()
	}

	c.mu.Lock()
	isPreRegistration := c.nick == ""
	fixBase := c.nickFixBase
	c.mu.Unlock()

	var newNick string
	switch {
	case isPreRegistration:
		// Reconnect path: library's counter handler was cleared; retry with "_".
		newNick = attempted + "_"
	case fixBase != "" && strings.EqualFold(attempted, fixBase+"_"):
		// Auto-fix: our rename attempt was also taken; try one more underscore.
		newNick = attempted + "_"
		c.mu.Lock()
		c.nickFixBase = attempted
		c.mu.Unlock()
	default:
		// Post-registration user-initiated /nick — surface error, do not retry.
		c.emitEvent(&core.StateConnectionEvent{
			State:   core.StateConnected,
			Message: fmt.Sprintf("Nick %s is already in use.", attempted),
		})
		return
	}

	c.emitEvent(&core.StateConnectionEvent{
		State:   core.StateConnected,
		Message: fmt.Sprintf("Nick %s is in use, trying %s.", attempted, newNick),
	})
	if err := c.client.Send("NICK", newNick); err != nil {
		c.LogServerError(fmt.Sprintf("Failed to change nick to %s: %s", newNick, err))
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

	event := &core.StateFrozenEvent{ConversationID: strings.ToLower(channel), Frozen: ""}
	event.Topic = topic
	c.emitEvent(event)
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
		event := &core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: conv.Frozen(), Name: conv.Name(), Topic: topic, Unread: conv.Unread()}
		c.emitEvent(event)
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

	event := &core.StateFrozenEvent{ConversationID: channel, Frozen: ""}
	event.Info = map[string]any{"topic_by": who}
	c.emitEvent(event)
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
		// Special "info" state event for user mode changes
		c.emitEvent(&core.StateInfoEvent{Info: map[string]any{
			"nick": c.Nick(),
			"mode": modeStr,
		}})
		return
	}

	from := msg.Nick()
	if from == "" {
		from = msg.Source
	}
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
			event := &core.StateModeEvent{
				ConversationID: convID,
				From:           from,
				Mode:           prefix + string(ch),
				Nick:           targetNick,
			}
			c.emitEvent(event)
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
		event := &core.StateModeEvent{ConversationID: convID, From: from, Mode: chanModeStr, Nick: "", ModeChanged: true, Args: ""}
		c.emitEvent(event)
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

	// If a mode query is pending, emit a SentEvent carrying the original request ID
	// so the frontend callback fires via Socket.js's ID-matching. This avoids showing
	// a "got mode" chat message for auto-refresh queries.
	c.mu.Lock()
	requestID, waiting := c.modeWaiters[convID]
	if waiting {
		delete(c.modeWaiters, convID)
	}
	c.mu.Unlock()

	if waiting {
		var modes map[string]bool
		if conv := c.GetConversation(convID); conv != nil {
			modes = conv.Modes()
		}
		c.emitEvent(&core.SentEvent{
			ConversationID: convID,
			Message:        "/mode",
			Command:        []string{"mode"},
			Data: map[string]any{
				"id":    requestID,
				"mode":  mode,
				"modes": modes,
			},
		})
		return
	}

	// No pending query — emit as a state event (e.g. unsolicited on some servers).
	event := &core.StateModeEvent{ConversationID: convID, From: "", Mode: mode, Nick: "", ModeChanged: false, Args: args}
	c.emitEvent(event)
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
		c.emitEvent(&core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: ""})
	}

	for _, raw := range nicks {
		mode, nick, user, host := parseNamesEntry(raw)
		p := core.Participant{Nick: nick, Mode: mode, User: user, Host: host}
		c.namesBuffer[channel] = append(c.namesBuffer[channel], p)
		conv.AddParticipant(p)
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
	requestID, waiting := c.namesWaiters[channel]
	if waiting {
		delete(c.namesWaiters, channel)
	}
	c.mu.Unlock()

	// If a names query is pending, emit a SentEvent carrying the original request ID
	// so the frontend callback fires via Socket.js's ID-matching. This avoids showing
	// a "got names" chat message for auto-refresh queries.
	if waiting {
		c.emitEvent(&core.SentEvent{
			ConversationID: channel,
			Message:        "/names " + channel,
			Command:        []string{"names"},
			Data: map[string]any{
				"id":           requestID,
				"participants": participants,
			},
		})
		return
	}

	// No pending query — emit as a state event (e.g. on join or manual /names command).
	c.emitEvent(&core.StateParticipantsEvent{ConversationID: channel, Participants: participants})
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
		c.whoisBuffer[nick] = &core.WhoisData{
			Nick:     msg.Params[1], // preserve original case
			Channels: make(map[string]any),
		}
	}
	w := c.whoisBuffer[nick]

	switch code {
	case ircevent.RPL_WHOISUSER: // <nick> <user> <host> * :<realname>
		if len(msg.Params) >= 4 {
			w.User = msg.Params[2]
			w.Host = msg.Params[3]
		}
		if len(msg.Params) >= 6 {
			w.Name = msg.Params[5]
		}
	case ircevent.RPL_WHOISSERVER: // <nick> <server> :<server info>
		if len(msg.Params) >= 3 {
			w.Server = msg.Params[2]
		}
		if len(msg.Params) >= 4 {
			w.ServerInfo = msg.Params[3]
		}
	case ircevent.RPL_WHOISIDLE: // <nick> <idle_seconds> <signon> :seconds idle
		if len(msg.Params) >= 3 {
			var secs int
			if _, err := fmt.Sscanf(msg.Params[2], "%d", &secs); err == nil {
				w.IdleFor = secs
			}
		}
	case ircevent.RPL_WHOISCHANNELS: // <nick> :<channels>
		if len(msg.Params) >= 3 {
			for ch := range strings.FieldsSeq(msg.Params[2]) {
				mode, chName := parseNickMode(ch) // reuse - same prefix format
				w.Channels[chName] = map[string]any{"mode": mode}
			}
		}
	case ircevent.RPL_WHOISCERTFP:
		if len(msg.Params) >= 3 {
			w.Fingerprint = msg.Params[2]
		}
	case ircevent.RPL_AWAY: // <nick> :<away message>
		if len(msg.Params) >= 3 {
			w.Away = msg.Params[2]
		}
	case ircevent.RPL_WHOISACCOUNT: // <nick> <account> :is logged in as
		if len(msg.Params) >= 3 {
			w.Account = msg.Params[2]
		}
	case ircevent.RPL_WHOISSECURE:
		w.Secure = true
	}
}

// handleEndOfWhois handles RPL_ENDOFWHOIS (318) - emits collected WHOIS data.
func (c *Connection) handleEndOfWhois(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	nick := strings.ToLower(msg.Params[1])

	c.mu.Lock()
	whoisData := c.whoisBuffer[nick]
	delete(c.whoisBuffer, nick)
	c.mu.Unlock()

	var whois map[string]any
	if whoisData == nil {
		whois = map[string]any{"nick": msg.Params[1]}
	} else {
		whois = whoisData.ToMap()
	}

	// Update conversation info if this is a private conversation
	conv := c.GetConversation(msg.Params[1])
	if conv != nil && conv.IsPrivate() {
		for key, value := range whois {
			conv.SetInfo(key, value)
		}
		conv.SetInfo("ts", time.Now().Unix())
		// Clear frozen state if whois succeeded
		if conv.Frozen() != "" {
			conv.SetFrozen("")
		}

		// Emit state update so frontend updates conversation.info
		event := &core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: conv.Frozen(), Info: conv.Info()}
		c.emitEvent(event)
	}

	convID := ""
	if conv != nil {
		convID = conv.ID()
	}
	c.emitEvent(&core.SentEvent{ConversationID: convID, Message: "/whois", Command: []string{"whois"}, Data: whois})
}

// handleIsonReply handles RPL_ISON (303).
// Format: :server 303 nick :nick1 nick2 ...
// Unfreezes private conversations for nicks that are online.
func (c *Connection) handleIsonReply(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	onlineNicks := strings.Fields(msg.Params[1])
	online := make(map[string]bool, len(onlineNicks))
	for _, nick := range onlineNicks {
		online[strings.ToLower(nick)] = true
	}

	for _, conv := range c.Conversations() {
		if !conv.IsPrivate() || conv.Frozen() == "" {
			continue
		}
		if !online[conv.ID()] {
			continue
		}
		conv.SetFrozen("")
		c.emitEvent(&core.StateFrozenEvent{ConversationID: conv.ID(), Frozen: conv.Frozen()})
	}

	c.saveState()
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

	event := &core.MessageEvent{ConversationID: convID, From: msg.Source, Message: message, Type: core.MessageTypeNotice, Highlight: false}
	event.TS = serverTimeOrNowRFC3339(msg)
	c.emitEvent(event)

	c.persistMessage(convID, msg.Source, message, core.MessageTypeNotice, false, serverTimeOrNow(msg), "", "", "")
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

	event := &core.MessageEvent{ConversationID: convID, From: msg.Source, Message: message, Type: core.MessageTypeError, Highlight: false}
	event.TS = serverTimeOrNowRFC3339(msg)
	c.emitEvent(event)

	c.persistMessage(convID, msg.Source, message, core.MessageTypeError, false, serverTimeOrNow(msg), "", "", "")
}

// handleUserModeIs handles RPL_UMODEIS (221).
func (c *Connection) handleUserModeIs(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	modeStr := msg.Params[1]
	c.SetInfo("mode", modeStr)
	c.emitInfo()
}

// handleWelcome handles RPL_WELCOME (001).
func (c *Connection) handleWelcome(msg ircmsg.Message) {
	c.SetInfo("server", msg.Source)
	c.emitInfo()
	c.handleNotice(msg)
}

// handleISupport handles RPL_ISUPPORT (005).
func (c *Connection) handleISupport(_ ircmsg.Message) {
	c.mu.RLock()
	client := c.client
	c.mu.RUnlock()
	if client == nil {
		return
	}

	for key, value := range client.ISupport() {
		if value != "" {
			c.SetInfo(strings.ToLower(key), value)
		} else {
			c.SetInfo(strings.ToLower(key), true)
		}
	}
	c.emitInfo()
}
