package core

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"net"
	"strings"
	"sync"
	"time"

	"github.com/ergochat/irc-go/ircevent"
	"github.com/ergochat/irc-go/ircmsg"
)

// Connection errors.
var (
	ErrNotConnected       = errors.New("not connected")
	ErrDoesNotWantConnect = errors.New("does not want to be connected")
	ErrNoTarget           = errors.New("cannot send message without a target")
	ErrUsageJoin          = errors.New("usage: /join #channel")
	ErrUsagePart          = errors.New("usage: /part #channel")
	ErrUsageMsg           = errors.New("usage: /msg target message")
	ErrUsageNick          = errors.New("usage: /nick newnick")
	ErrUsageKick          = errors.New("usage: /kick nick [reason]")
	ErrUsageMe            = errors.New("usage: /me action")
	ErrUsageSay           = errors.New("usage: /say message")
	ErrUsageWhois         = errors.New("usage: /whois nick")
	ErrUsageQuery         = errors.New("usage: /query <nick> [message]")
)

// IRCConnection represents a connection to an IRC server.
type IRCConnection struct {
	*BaseConnection
	ircMu sync.RWMutex
	nick  string

	// IRC client
	client *ircevent.Connection

	// Buffers for accumulating multi-message IRC replies
	namesBuffer map[string][]map[string]any // channel -> participants
	whoisBuffer map[string]map[string]any   // nick -> whois data

	// Reconnect state
	reconnectDelay time.Duration
	stopReconnect  chan struct{}

	// For testing
	DialContext func(ctx context.Context, network, addr string) (net.Conn, error)
}

// NewIRCConnection creates a new IRC connection.
func NewIRCConnection(rawURL string, user *User) *IRCConnection {
	return &IRCConnection{
		BaseConnection: NewBaseConnection(rawURL, user),
		namesBuffer:    make(map[string][]map[string]any),
		whoisBuffer:    make(map[string]map[string]any),
	}
}

// Connect initiates an IRC connection.
func (c *IRCConnection) Connect() error {
	c.ircMu.Lock()

	if c.state == StateConnected || c.state == StateConnecting {
		c.ircMu.Unlock()
		return nil
	}

	if c.wantedState != StateConnected {
		c.ircMu.Unlock()
		return ErrDoesNotWantConnect
	}

	c.state = StateConnecting

	// Stop any pending reconnect loop
	if c.stopReconnect != nil {
		close(c.stopReconnect)
	}
	c.stopReconnect = make(chan struct{})

	c.emitState("connecting", fmt.Sprintf("Connecting to %s.", c.url.Host))

	// Get nickname and other config while holding the lock
	nick := c.BaseConnection.Nick()
	host := c.url.Host
	userEmail := c.user.Email()
	useTLS := c.url.Scheme == "ircs"
	if tlsParam := c.url.Query().Get("tls"); tlsParam != "" {
		useTLS = tlsParam != "0"
	} else if !useTLS {
		useTLS = true
	}
	dialContext := c.DialContext

	var urlUser, urlPass string
	if c.url.User != nil {
		urlUser = c.url.User.Username()
		urlPass, _ = c.url.User.Password()
	}

	saslMech := strings.ToUpper(c.url.Query().Get("sasl"))

	c.client = &ircevent.Connection{
		Server:        host,
		Nick:          nick,
		User:          userEmail,
		RealName:      userEmail,
		UseTLS:        useTLS,
		ReconnectFreq: 0,
		QuitMessage:   "Bye!",
		Debug:         false,
		DialContext:   dialContext,
	}

	if saslMech == "PLAIN" || saslMech == "EXTERNAL" {
		saslLogin := urlUser
		if saslLogin == "" {
			saslLogin = nick
		}
		c.client.UseSASL = true
		c.client.SASLMech = saslMech
		c.client.SASLLogin = saslLogin
		c.client.SASLPassword = urlPass
		c.client.SASLOptional = true
		c.client.RequestCaps = []string{"sasl"}
	} else if urlPass != "" {
		c.client.Password = urlPass
	}

	if useTLS {
		tlsVerify := c.url.Query().Get("tls_verify") == "1"
		c.client.TLSConfig = &tls.Config{
			InsecureSkipVerify: !tlsVerify, //nolint:gosec // Allow user to connect to local irc servers with self-signed certs by disabling verification
		}
	}

	// Set up callbacks before releasing lock and connecting.

	c.client.AddConnectCallback(func(msg ircmsg.Message) {
		c.ircMu.Lock()
		c.state = StateConnected
		c.nick = c.client.CurrentNick()
		c.reconnectDelay = 0
		c.ircMu.Unlock()

		// Store acknowledged capabilities and SASL status
		caps := c.client.AcknowledgedCaps()
		if len(caps) > 0 {
			capList := make([]string, 0, len(caps))
			for k := range caps {
				capList = append(capList, k)
			}
			c.SetInfo("capabilities", capList)
		}

		saslMech := strings.ToUpper(c.url.Query().Get("sasl"))
		if saslMech != "" {
			_, saslAcked := caps["sasl"]
			c.SetInfo("authenticated", saslAcked)
		}

		c.emitState("connected", fmt.Sprintf("Connected to %s.", c.url.Host))
		c.emitInfo()

		// Execute on-connect commands
		c.ircMu.RLock()
		cmds := c.onConnectCommands
		c.ircMu.RUnlock()
		for _, cmd := range cmds {
			c.executeCommand(cmd)
		}

		// Rejoin saved channels
		for _, conv := range c.Conversations() {
			name := conv.Name()
			if strings.HasPrefix(name, "#") || strings.HasPrefix(name, "&") {
				err := c.client.Join(name)
				if err != nil {
					slog.Error("Failed to rejoin channel on connect", "channel", name, "error", err)
				}
			}
		}
	})

	c.client.AddDisconnectCallback(func(msg ircmsg.Message) {
		c.ircMu.Lock()
		c.state = StateDisconnected
		wantConnect := c.wantedState == StateConnected
		c.ircMu.Unlock()
		c.emitState("disconnected", fmt.Sprintf("Disconnected from %s.", c.url.Host))

		// Freeze all conversations
		for _, conv := range c.Conversations() {
			conv.SetFrozen("Disconnected.")
			c.emitEvent(map[string]any{
				"event":           "state",
				"type":            "frozen",
				"conversation_id": conv.ID(),
				"frozen":          conv.Frozen(),
			})
		}

		if wantConnect {
			go c.reconnectLoop()
		}
	})

	c.client.AddCallback("PRIVMSG", func(msg ircmsg.Message) {
		c.handleMessage(msg, "private")
	})

	c.client.AddCallback("NOTICE", func(msg ircmsg.Message) {
		c.handleMessage(msg, "notice")
	})

	c.client.AddCallback("JOIN", func(msg ircmsg.Message) {
		c.handleJoin(msg)
	})

	c.client.AddCallback("PART", func(msg ircmsg.Message) {
		c.handlePart(msg)
	})

	c.client.AddCallback("QUIT", func(msg ircmsg.Message) {
		c.handleQuit(msg)
	})

	c.client.AddCallback("NICK", func(msg ircmsg.Message) {
		c.handleNick(msg)
	})

	c.client.AddCallback("KICK", func(msg ircmsg.Message) {
		c.handleKick(msg)
	})

	c.client.AddCallback("INVITE", func(msg ircmsg.Message) {
		c.handleInvite(msg)
	})

	c.client.AddCallback("TOPIC", func(msg ircmsg.Message) {
		c.handleTopic(msg)
	})

	c.client.AddCallback("MODE", func(msg ircmsg.Message) {
		c.handleMode(msg)
	})

	c.client.AddCallback(ircevent.RPL_WELCOME, func(msg ircmsg.Message) {
		c.handleWelcome(msg)
	})

	c.client.AddCallback(ircevent.RPL_ISUPPORT, func(msg ircmsg.Message) {
		c.handleISupport(msg)
	})

	c.client.AddCallback(ircevent.RPL_TOPIC, func(msg ircmsg.Message) {
		c.handleTopicReply(msg)
	})

	c.client.AddCallback(ircevent.RPL_TOPICTIME, func(msg ircmsg.Message) {
		c.handleTopicWhoTime(msg)
	})

	for _, code := range []string{
		ircevent.RPL_YOURHOST, ircevent.RPL_CREATED, ircevent.RPL_MYINFO,
		ircevent.RPL_MOTD, ircevent.RPL_MOTDSTART, ircevent.RPL_ENDOFMOTD,
		ircevent.RPL_SASLSUCCESS, ircevent.ERR_SASLFAIL, ircevent.ERR_SASLTOOLONG,
		ircevent.ERR_SASLABORTED, ircevent.ERR_SASLALREADY, ircevent.RPL_SASLMECHS,
	} {
		c.client.AddCallback(code, func(msg ircmsg.Message) {
			c.handleNotice(msg)
		})
	}

	c.client.AddCallback(ircevent.RPL_CHANNELMODEIS, func(msg ircmsg.Message) {
		c.handleChannelModeIs(msg)
	})

	c.client.AddCallback(ircevent.RPL_NAMREPLY, func(msg ircmsg.Message) {
		c.handleNamesReply(msg)
	})

	c.client.AddCallback(ircevent.RPL_ENDOFNAMES, func(msg ircmsg.Message) {
		c.handleEndOfNames(msg)
	})

	c.client.AddCallback(ircevent.ERR_NICKNAMEINUSE, func(msg ircmsg.Message) {
		c.handleNickInUse(msg)
	})

	// WHOIS response numerics
	for _, code := range []string{
		ircevent.RPL_WHOISUSER, ircevent.RPL_WHOISSERVER, ircevent.RPL_WHOISIDLE,
		ircevent.RPL_WHOISCHANNELS, ircevent.RPL_WHOISCERTFP, ircevent.RPL_AWAY,
		ircevent.RPL_WHOISACCOUNT, ircevent.RPL_WHOISSECURE,
	} {
		c.client.AddCallback(code, func(msg ircmsg.Message) {
			c.handleWhoisReply(code, msg)
		})
	}
	c.client.AddCallback(ircevent.RPL_ENDOFWHOIS, func(msg ircmsg.Message) {
		c.handleEndOfWhois(msg)
	})

	// Capture client for local use to avoid needing lock
	client := c.client
	c.ircMu.Unlock()

	go client.Loop()

	// Connect to server (without holding the lock)
	if err := client.Connect(); err != nil {
		c.ircMu.Lock()
		c.state = StateDisconnected
		c.ircMu.Unlock()
		c.emitState("disconnected", fmt.Sprintf("Could not connect to %s: %s", host, err))
		return err
	}

	return nil
}

// Disconnect closes the IRC connection.
func (c *IRCConnection) Disconnect() error {
	c.ircMu.Lock()
	defer c.ircMu.Unlock()

	// Stop any pending reconnect loop
	if c.stopReconnect != nil {
		close(c.stopReconnect)
		c.stopReconnect = nil
	}

	if c.state == StateDisconnected || c.state == StateDisconnecting {
		return nil
	}

	c.state = StateDisconnecting

	if c.client != nil && c.client.Connected() {
		c.client.Quit()
	}

	c.state = StateDisconnected
	return nil
}

// Send sends a message or command to a target (channel or user).
// Messages starting with "/" are interpreted as IRC commands.
func (c *IRCConnection) Send(target, message string) error {
	c.ircMu.RLock()
	if c.state != StateConnected || c.client == nil {
		c.ircMu.RUnlock()
		return ErrNotConnected
	}
	c.ircMu.RUnlock()

	// Handle IRC commands (messages starting with /)
	if strings.HasPrefix(message, "/") {
		return c.handleCommand(target, message[1:])
	}

	if target == "" {
		return ErrNoTarget
	}

	if err := c.client.Privmsg(target, message); err != nil {
		return err
	}

	c.emitSentMessage(target, message, "private")
	return nil
}

// handleCommand parses and executes an IRC command from user input.
func (c *IRCConnection) handleCommand(target, raw string) error {
	parts := strings.SplitN(raw, " ", 2)
	command := strings.ToUpper(parts[0])
	args := ""
	if len(parts) > 1 {
		args = parts[1]
	}

	switch command {
	case "JOIN", "J":
		if args == "" {
			return ErrUsageJoin
		}
		return c.client.Join(strings.SplitN(args, " ", 2)[0])
	case "PART", "LEAVE", "CLOSE":
		ch := target
		if args != "" {
			ch = strings.SplitN(args, " ", 2)[0]
		}
		if ch == "" {
			return ErrUsagePart
		}
		return c.client.Part(ch)
	case "MSG":
		msgParts := strings.SplitN(args, " ", 2)
		if len(msgParts) < 2 {
			return ErrUsageMsg
		}
		if err := c.client.Privmsg(msgParts[0], msgParts[1]); err != nil {
			return err
		}
		c.emitSentMessage(msgParts[0], msgParts[1], "private")
		return nil
	case "NICK":
		if args == "" {
			return ErrUsageNick
		}
		return c.client.Send("NICK", args)
	case "TOPIC":
		if args != "" {
			return c.client.Send("TOPIC", target, args)
		}
		return c.client.Send("TOPIC", target)
	case "KICK":
		kickParts := strings.SplitN(args, " ", 2)
		if len(kickParts) == 0 || kickParts[0] == "" {
			return ErrUsageKick
		}
		if len(kickParts) == 2 {
			return c.client.Send("KICK", target, kickParts[0], kickParts[1])
		}
		return c.client.Send("KICK", target, kickParts[0])
	case "MODE":
		if args != "" {
			// /mode +o nick → MODE <target> +o nick
			// /mode #channel +o nick → MODE #channel +o nick
			parts := strings.SplitN(args, " ", 2)
			if strings.HasPrefix(parts[0], "#") || strings.HasPrefix(parts[0], "&") {
				return c.client.SendRaw("MODE " + args)
			}
			if target != "" {
				return c.client.SendRaw("MODE " + target + " " + args)
			}
			return c.client.SendRaw("MODE " + args)
		}
		// /mode with no args → query mode of current target
		if target != "" {
			return c.client.Send("MODE", target)
		}
		return nil
	case "ME":
		if target == "" || args == "" {
			return ErrUsageMe
		}
		if err := c.client.Privmsg(target, "\x01ACTION "+args+"\x01"); err != nil {
			return err
		}
		c.emitSentMessage(target, args, "action")
		return nil
	case "SAY":
		if target == "" || args == "" {
			return ErrUsageSay
		}
		if err := c.client.Privmsg(target, args); err != nil {
			return err
		}
		c.emitSentMessage(target, args, "private")
		return nil
	case "WHOIS":
		nick := args
		if nick == "" {
			return ErrUsageWhois
		}
		return c.client.Send("WHOIS", nick)
	case "QUERY":
		parts := strings.Fields(args)
		if len(parts) == 0 {
			return ErrUsageQuery
		}
		nick := parts[0]
		convID := strings.ToLower(nick)
		conv := c.GetConversation(convID)
		if conv == nil {
			conv = NewConversation(convID, c)
			c.AddConversation(conv)
		}
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

		if len(parts) > 1 {
			msg := strings.Join(parts[1:], " ")
			return c.Send(nick, msg)
		}
		return nil
	case "QUIT":
		msg := "Bye!"
		if args != "" {
			msg = args
		}
		c.client.QuitMessage = msg
		c.client.Quit()
		return nil
	default:
		// Send as raw IRC command
		return c.client.SendRaw(raw)
	}
}

// Nick returns the current IRC nickname.
func (c *IRCConnection) Nick() string {
	c.ircMu.RLock()
	if c.nick != "" {
		c.ircMu.RUnlock()
		return c.nick
	}
	c.ircMu.RUnlock()

	// Fall back to base implementation
	return c.BaseConnection.Nick()
}

// SetNick sets the current nickname.
func (c *IRCConnection) SetNick(nick string) {
	c.ircMu.Lock()
	defer c.ircMu.Unlock()
	c.nick = nick
}

// saveState persists the connection (including conversations) to the backend.
func (c *IRCConnection) saveState() {
	if err := c.user.Core().Backend().SaveConnection(c); err != nil {
		c.user.Core().Events().EmitUser(c.user.ID(), map[string]any{
			"event":         "state",
			"type":          "connection",
			"connection_id": c.ID(),
			"message":       "Failed to save connection state: " + err.Error(),
		})
	}
}

// emitSentMessage emits a message event for a message the user sent,
// so the frontend can display it. IRC servers don't echo your own messages back.
func (c *IRCConnection) emitSentMessage(target, message, msgType string) {
	convID := strings.ToLower(target)
	from := c.Nick()

	c.emitEvent(map[string]any{
		"event":           "message",
		"conversation_id": convID,
		"from":            from,
		"highlight":       false,
		"message":         message,
		"type":            msgType,
	})

	c.persistMessage(convID, from, message, msgType, false)
}

// persistNotification saves a highlighted message to the user's notification log.
func (c *IRCConnection) persistNotification(convID, from, message, msgType string) {
	msg := Notification{
		ConnectionID:   c.ID(),
		ConversationID: convID,
		From:           from,
		Message:        message,
		Type:           msgType,
		Timestamp:      time.Now().Unix(),
	}
	err := c.user.Core().Backend().SaveNotification(c.user, msg)
	if err != nil {
		slog.Error("Failed to save notification", "error", err)
	}
}

// persistMessage saves a message to the backend storage.
func (c *IRCConnection) persistMessage(convID, from, message, msgType string, highlight bool) {
	conv := c.GetConversation(convID)
	if conv == nil {
		slog.Warn("Conversation not found for message", "conversation_id", convID)
		return
	}

	msg := Message{
		From:      from,
		Message:   message,
		Type:      msgType,
		Highlight: highlight,
		Timestamp: time.Now().Unix(),
	}

	err := c.user.Core().Backend().SaveMessage(conv, msg)
	if err != nil {
		slog.Error("Failed to save message", "conversation_id", convID, "error", err)
	}
}

// emitEvent emits an event to the user's event subscribers.
func (c *IRCConnection) emitEvent(event map[string]any) {
	event["connection_id"] = c.ID()
	c.user.Core().Events().EmitUser(c.user.ID(), event)
}

// emitState emits a connection state change event.
func (c *IRCConnection) emitState(state, message string) {
	c.emitEvent(map[string]any{
		"event":   "state",
		"type":    "connection",
		"state":   state,
		"message": message,
	})
}

// emitInfo emits the connection info (nick, server details).
func (c *IRCConnection) emitInfo() {
	c.ircMu.RLock()
	info := map[string]any{
		"event": "state",
		"type":  "me",
		"nick":  c.nick,
	}
	maps.Copy(info, c.info)
	c.ircMu.RUnlock()
	c.emitEvent(info)
}

// executeCommand runs an on-connect command (e.g., /join #channel, /msg NickServ ...).
func (c *IRCConnection) executeCommand(cmd string) {
	cmd = strings.TrimSpace(cmd)
	if cmd == "" {
		return
	}

	// Strip leading /
	cmd = strings.TrimPrefix(cmd, "/")

	parts := strings.SplitN(cmd, " ", 2)
	command := strings.ToUpper(parts[0])
	args := ""
	if len(parts) > 1 {
		args = parts[1]
	}

	switch command {
	case "JOIN":
		if args != "" {
			if err := c.client.Join(args); err != nil {
				slog.Error("Failed to execute on-connect JOIN command", "channel", args, "error", err)
			}
		}
	case "MSG", "PRIVMSG":
		msgParts := strings.SplitN(args, " ", 2)
		if len(msgParts) == 2 {
			if err := c.client.Privmsg(msgParts[0], msgParts[1]); err != nil {
				slog.Error("Failed to execute on-connect MSG command", "target", msgParts[0], "error", err)
			}
		}
	default:
		// Send raw IRC command
		if err := c.client.SendRaw(cmd); err != nil {
			slog.Error("Failed to execute on-connect command", "command", cmd, "error", err)
		}
	}
}

// handleMessage handles incoming PRIVMSG and NOTICE messages.
func (c *IRCConnection) handleMessage(msg ircmsg.Message, msgType string) {
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
	if target == c.Nick() {
		// Private message - use sender's nick as conversation ID
		convID = nick
	}

	// Get or create conversation
	conv := c.GetConversation(convID)
	if conv == nil {
		conv = NewConversation(convID, c)
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

// isHighlight checks if a message should be highlighted for this user.
func (c *IRCConnection) isHighlight(message string) bool {
	currentNick := c.Nick()
	if currentNick != "" && strings.Contains(strings.ToLower(message), strings.ToLower(currentNick)) {
		return true
	}

	keywords := c.user.HighlightKeywords()
	lowerMsg := strings.ToLower(message)
	for _, kw := range keywords {
		if kw != "" && strings.Contains(lowerMsg, strings.ToLower(kw)) {
			return true
		}
	}

	return false
}

// handleJoin handles JOIN messages.
func (c *IRCConnection) handleJoin(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	channel := msg.Params[0]
	nick := msg.Nick()

	if nick == c.Nick() {
		// We joined - create/get conversation and emit frozen event
		conv := c.GetConversation(channel)
		if conv == nil {
			conv = NewConversation(channel, c)
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
			conv = NewConversation(channel, c)
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
func (c *IRCConnection) handlePart(msg ircmsg.Message) {
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
func (c *IRCConnection) handleQuit(msg ircmsg.Message) {
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

// handleNick handles NICK change messages.
func (c *IRCConnection) handleNick(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}

	oldNick := msg.Nick()
	newNick := msg.Params[0]

	if oldNick == c.Nick() {
		// Our nick changed
		c.ircMu.Lock()
		c.nick = newNick
		c.ircMu.Unlock()
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

// handleTopic handles TOPIC messages (topic changed by a user).
func (c *IRCConnection) handleTopic(msg ircmsg.Message) {
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
func (c *IRCConnection) handleTopicReply(msg ircmsg.Message) {
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

// handleNamesReply handles RPL_NAMREPLY (353) - accumulates channel members.
// Format: :<server> 353 <nick> <type> <channel> :<nicks...>
func (c *IRCConnection) handleNamesReply(msg ircmsg.Message) {
	if len(msg.Params) < 4 {
		return
	}

	channel := strings.ToLower(msg.Params[2])
	nicks := strings.Fields(msg.Params[3])

	c.ircMu.Lock()
	defer c.ircMu.Unlock()

	conv := c.GetConversation(channel)
	if conv == nil {
		conv = NewConversation(channel, c)
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
func (c *IRCConnection) handleEndOfNames(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	channel := strings.ToLower(msg.Params[1])

	c.ircMu.Lock()
	participants := c.namesBuffer[channel]
	delete(c.namesBuffer, channel)
	c.ircMu.Unlock()

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

// handleWhoisReply collects WHOIS response numerics into the buffer.
func (c *IRCConnection) handleWhoisReply(code string, msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	nick := strings.ToLower(msg.Params[1])

	c.ircMu.Lock()
	defer c.ircMu.Unlock()

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
func (c *IRCConnection) handleEndOfWhois(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	nick := strings.ToLower(msg.Params[1])

	c.ircMu.Lock()
	whois := c.whoisBuffer[nick]
	delete(c.whoisBuffer, nick)
	c.ircMu.Unlock()

	if whois == nil {
		whois = map[string]any{"nick": msg.Params[1]}
	}

	whois["event"] = "sent"
	whois["message"] = "/whois"
	whois["command"] = []string{"whois"}
	c.emitEvent(whois)
}

// handleCTCP responds to CTCP queries (PING, VERSION, TIME).
func (c *IRCConnection) handleCTCP(nick, ctcp string) {
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

// handleKick handles KICK messages.
// Format: :nick!user@host KICK #channel target :reason
func (c *IRCConnection) handleKick(msg ircmsg.Message) {
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
func (c *IRCConnection) handleInvite(msg ircmsg.Message) {
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

// reconnectLoop attempts to reconnect with exponential backoff.
func (c *IRCConnection) reconnectLoop() {
	const (
		minDelay = 2 * time.Second
		maxDelay = 5 * time.Minute
	)

	c.ircMu.Lock()
	if c.reconnectDelay < minDelay {
		c.reconnectDelay = minDelay
	} else {
		c.reconnectDelay *= 2
		if c.reconnectDelay > maxDelay {
			c.reconnectDelay = maxDelay
		}
	}
	delay := c.reconnectDelay
	stop := c.stopReconnect
	c.ircMu.Unlock()

	c.emitState("queued", fmt.Sprintf("Reconnecting in %s.", delay.Truncate(time.Second)))

	select {
	case <-time.After(delay):
		// Continue to reconnect
	case <-stop:
		return
	}

	c.ircMu.RLock()
	want := c.wantedState
	c.ircMu.RUnlock()

	if want != StateConnected {
		return
	}

	if err := c.Connect(); err != nil {
		// Connect failed immediately; the disconnect callback will fire another reconnectLoop
		return
	}
}

// handleNickInUse handles ERR_NICKNAMEINUSE (433) by appending "_" and retrying.
func (c *IRCConnection) handleNickInUse(msg ircmsg.Message) {
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

// handleMode handles MODE messages.
func (c *IRCConnection) handleMode(msg ircmsg.Message) {
	if len(msg.Params) < 2 {
		return
	}

	target := msg.Params[0]
	modeStr := msg.Params[1]

	// User mode change (not a channel)
	if !ChannelRE.MatchString(target) {
		c.emitEvent(map[string]any{
			"event": "state",
			"type":  "me",
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
func (c *IRCConnection) handleChannelModeIs(msg ircmsg.Message) {
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

// handleNotice handles server numerics that should be displayed as notices.
func (c *IRCConnection) handleNotice(msg ircmsg.Message) {
	if len(msg.Params) < 1 {
		return
	}
	message := msg.Params[len(msg.Params)-1]
	convID := ""

	// Ensure server conversation exists (empty ID matches Perl behavior)
	conv := c.GetConversation(convID)
	if conv == nil {
		conv = NewConversationWithID("", c.Name(), c)
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

// handleWelcome handles RPL_WELCOME (001).
func (c *IRCConnection) handleWelcome(msg ircmsg.Message) {
	c.SetInfo("server", msg.Source)
	c.emitInfo()
	c.handleNotice(msg)
}

// handleISupport handles RPL_ISUPPORT (005).
func (c *IRCConnection) handleISupport(msg ircmsg.Message) {
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

// handleTopicWhoTime handles RPL_TOPICWHOTIME (333).
func (c *IRCConnection) handleTopicWhoTime(msg ircmsg.Message) {
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

// Ensure IRCConnection implements Connection interface.
var _ Connection = (*IRCConnection)(nil)
