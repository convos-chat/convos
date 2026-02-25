// Package irc implements an IRC connection for Convos.
package irc

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

	"github.com/convos-chat/convos/pkg/core"
	"github.com/ergochat/irc-go/ircevent"
	"github.com/ergochat/irc-go/ircmsg"
)

// Connection errors.
var (
	ErrNotConnected        = errors.New("not connected")
	ErrDoesNotWantConnect  = errors.New("does not want to be connected")
	ErrNoTarget            = errors.New("cannot send message without a target")
	ErrUnknownConversation = errors.New("unknown conversation")
)

// userModeChars are IRC mode characters that target a specific user (nick) in a channel.
const userModeChars = "ovhaq"

// listCache stores cached LIST results for channel discovery.
type listCache struct {
	conversations map[string]listEntry // keyed by channel name
	done          bool
	ts            time.Time
}

// listEntry represents a single channel from a LIST response.
type listEntry struct {
	Name           string `json:"name"`
	ConversationID string `json:"conversation_id"`
	NUsers         int    `json:"n_users"`
	Topic          string `json:"topic"`
}

// Connection represents a connection to an IRC server.
type Connection struct {
	*core.BaseConnection
	mu   sync.RWMutex
	nick string

	// IRC client
	client *ircevent.Connection

	// Buffers for accumulating multi-message IRC replies
	namesBuffer map[string][]map[string]any // channel -> participants
	whoisBuffer map[string]map[string]any   // nick -> whois data
	listBuf     listCache                   // cached LIST results

	// Reconnect state
	reconnectDelay time.Duration
	stopReconnect  chan struct{}

	// For testing
	DialContext func(ctx context.Context, network, addr string) (net.Conn, error)
}

// NewConnection creates a new IRC connection.
func NewConnection(rawURL string, user *core.User) *Connection {
	return &Connection{
		BaseConnection: core.NewBaseConnection(rawURL, user),
		namesBuffer:    make(map[string][]map[string]any),
		whoisBuffer:    make(map[string]map[string]any),
	}
}

// Connect initiates an IRC connection.
func (c *Connection) Connect() error {
	c.mu.Lock()

	slog.Info("Attempting to connect", "url", c.URL().String())
	state := c.State()
	if state == core.StateConnected || state == core.StateConnecting {
		c.mu.Unlock()
		return nil
	}

	if c.WantedState() != core.StateConnected {
		c.mu.Unlock()
		return ErrDoesNotWantConnect
	}

	c.SetState(core.StateConnecting)

	// Stop any pending reconnect loop. Use select to avoid closing an already
	// closed channel (Disconnect leaves a pre-closed channel to short-circuit
	// any reconnect loop that fires after it).
	if c.stopReconnect != nil {
		select {
		case <-c.stopReconnect:
			// already closed; nothing to do
		default:
			close(c.stopReconnect)
		}
	}
	c.stopReconnect = make(chan struct{})

	url := c.URL()
	c.emitState("connecting", fmt.Sprintf("Connecting to %s.", url.Host))

	// Get nickname and other config while holding the lock
	nick := c.BaseConnection.Nick()
	host := url.Host
	userEmail := c.User().Email()
	useTLS := url.Scheme == "ircs"
	if tlsParam := url.Query().Get("tls"); tlsParam != "" {
		useTLS = tlsParam != "0"
	} else if !useTLS {
		useTLS = true
	}
	dialContext := c.DialContext

	var urlUser, urlPass string
	if url.User != nil {
		urlUser = url.User.Username()
		urlPass, _ = url.User.Password()
	}

	saslMech := strings.ToUpper(url.Query().Get("sasl"))

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

	// WEBIRC support via profile
	if profile := c.Profile(); profile != nil {
		if webircPass := profile.WebircPassword(); webircPass != "" {
			remoteAddr := c.User().RemoteAddress()
			hostname := remoteAddr
			// Try to resolve hostname, but don't block too long or fail hard
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			if names, err := net.DefaultResolver.LookupAddr(ctx, remoteAddr); err == nil && len(names) > 0 {
				hostname = strings.TrimSuffix(names[0], ".")
			}
			c.client.WebIRC = []string{webircPass, "convos", hostname, remoteAddr}
		}
	}

	c.client.RequestCaps = []string{"message-tags", "server-time", "multi-prefix", "userhost-in-names", "extended-join"}

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
		c.client.RequestCaps = append(c.client.RequestCaps, "sasl")
	} else if urlPass != "" {
		c.client.Password = urlPass
	}

	if useTLS {
		tlsVerify := url.Query().Get("tls_verify") == "1"
		c.client.TLSConfig = &tls.Config{
			InsecureSkipVerify: !tlsVerify, //nolint:gosec // Allow user to connect to local irc servers with self-signed certs by disabling verification
		}
	}

	// Set up callbacks before releasing lock and connecting.

	c.client.AddConnectCallback(func(msg ircmsg.Message) {
		c.mu.Lock()
		c.SetState(core.StateConnected)
		c.nick = c.client.CurrentNick()
		c.reconnectDelay = 0
		c.mu.Unlock()

		// Store acknowledged capabilities and SASL status
		caps := c.client.AcknowledgedCaps()
		if len(caps) > 0 {
			capList := make([]string, 0, len(caps))
			for k := range caps {
				capList = append(capList, k)
			}
			c.SetInfo("capabilities", capList)
		}

		connURL := c.URL()
		saslMech := strings.ToUpper(connURL.Query().Get("sasl"))
		if saslMech != "" {
			_, saslAcked := caps["sasl"]
			c.SetInfo("authenticated", saslAcked)
		}

		c.emitState(string(core.StateConnected), fmt.Sprintf("Connected to %s.", connURL.Host))
		c.emitInfo()

		// Execute on-connect commands
		cmds := c.OnConnectCommands()
		for _, cmd := range cmds {
			c.executeCommand(cmd)
		}

		// Rejoin saved channels and collect frozen private conversation nicks for ISON
		var isonNicks []string
		for _, conv := range c.Conversations() {
			name := conv.Name()
			if strings.HasPrefix(name, "#") || strings.HasPrefix(name, "&") {
				err := c.client.Join(name)
				if err != nil {
					c.LogServerError(fmt.Sprintf("Failed to rejoin channel %s: %s", name, err))
				}
			} else if conv.Frozen() != "" {
				isonNicks = append(isonNicks, name)
			}
		}

		// Send ISON to check if private conversation nicks are online
		if len(isonNicks) > 0 {
			if err := c.client.Send("ISON", strings.Join(isonNicks, " ")); err != nil {
				c.LogServerError(fmt.Sprintf("Failed to check online status: %s", err))
			}
		}
	})

	c.client.AddDisconnectCallback(func(msg ircmsg.Message) {
		c.SetState(core.StateDisconnected)
		wantConnect := c.WantedState() == core.StateConnected
		disconnectMsg := fmt.Sprintf("Disconnected from %s.", c.URL().Host)
		c.emitState(string(core.StateDisconnected), disconnectMsg)
		c.LogServerError(disconnectMsg)

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

	c.client.AddCallback("TAGMSG", func(msg ircmsg.Message) {
		c.handleTagMsg(msg)
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

	// Add handler for user mode (RPL_UMODEIS / 221)
	c.client.AddCallback(ircevent.RPL_UMODEIS, func(msg ircmsg.Message) {
		c.handleUserModeIs(msg)
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

	c.client.AddCallback(ircevent.RPL_ISON, func(msg ircmsg.Message) {
		c.handleIsonReply(msg)
	})

	// LIST response accumulation
	c.client.AddCallback(ircevent.RPL_LIST, func(msg ircmsg.Message) {
		c.handleListReply(msg)
	})
	c.client.AddCallback(ircevent.RPL_LISTEND, func(msg ircmsg.Message) {
		c.handleListEnd()
	})

	// Common IRC error numerics — surface them so the user gets feedback
	// when a command fails (e.g., "You're not channel operator").
	for _, code := range []string{
		ircevent.ERR_NOSUCHNICK, ircevent.ERR_NOSUCHSERVER, ircevent.ERR_NOSUCHCHANNEL,
		ircevent.ERR_CANNOTSENDTOCHAN, ircevent.ERR_TOOMANYCHANNELS, ircevent.ERR_TOOMANYTARGETS,
		ircevent.ERR_UNKNOWNCOMMAND, ircevent.ERR_NEEDMOREPARAMS,
		ircevent.ERR_USERNOTINCHANNEL, ircevent.ERR_NOTONCHANNEL, ircevent.ERR_USERONCHANNEL,
		ircevent.ERR_CHANNELISFULL, ircevent.ERR_UNKNOWNMODE,
		ircevent.ERR_INVITEONLYCHAN, ircevent.ERR_BANNEDFROMCHAN, ircevent.ERR_BADCHANNELKEY,
		ircevent.ERR_BADCHANMASK, ircevent.ERR_BANLISTFULL,
		ircevent.ERR_NOPRIVILEGES, ircevent.ERR_CHANOPRIVSNEEDED, ircevent.ERR_UNIQOPPRIVSNEEDED,
		ircevent.ERR_NOOPERHOST, ircevent.ERR_PASSWDMISMATCH,
	} {
		c.client.AddCallback(code, func(msg ircmsg.Message) {
			c.handleErrorReply(msg)
		})
	}

	// Capture client for local use to avoid needing lock
	client := c.client
	c.mu.Unlock()

	go client.Loop()

	// Connect to server (without holding the lock)
	if err := client.Connect(); err != nil {
		c.SetState(core.StateDisconnected)
		errMsg := fmt.Sprintf("Could not connect to %s: %s", host, err)
		c.emitState(string(core.StateDisconnected), errMsg)
		c.LogServerError(errMsg)
		return err
	}

	return nil
}

// Disconnect closes the IRC connection.
func (c *Connection) Disconnect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Stop any pending reconnect loop and leave a pre-closed channel so that
	// any reconnectLoop spawned by the subsequent disconnect callback also
	// exits immediately (receiving from a nil channel blocks forever).
	if c.stopReconnect != nil {
		select {
		case <-c.stopReconnect:
			// already closed; nothing to do
		default:
			close(c.stopReconnect)
		}
	}
	stopped := make(chan struct{})
	close(stopped)
	c.stopReconnect = stopped

	state := c.State()
	if state == core.StateDisconnected || state == core.StateDisconnecting {
		return nil
	}

	c.SetState(core.StateDisconnecting)

	if c.client != nil && c.client.Connected() {
		c.client.Quit()
	}

	c.SetState(core.StateDisconnected)
	return nil
}

// LogServerError logs an error message to the server log (visible in UI).
func (c *Connection) LogServerError(message string) {
	convID := ""
	conv := c.GetConversation(convID)
	if conv == nil {
		conv = core.NewConversationWithID("", c.Name(), c)
		c.AddConversation(conv)
	}

	ts := time.Now().Unix()
	c.emitEvent(map[string]any{
		"event":           "message",
		"conversation_id": convID,
		"from":            c.URL().Host,
		"message":         message,
		"type":            "error",
		"ts":              time.Unix(ts, 0).Format(time.RFC3339),
	})
	c.persistMessage(convID, c.URL().Host, message, "error", false, ts, "", "", "")
}

// Nick returns the current IRC nickname.
func (c *Connection) Nick() string {
	c.mu.RLock()
	if c.nick != "" {
		c.mu.RUnlock()
		return c.nick
	}
	c.mu.RUnlock()

	// Fall back to base implementation
	return c.BaseConnection.Nick()
}

// Send sends a message or command to a target (channel or user).
// Messages starting with "/" are interpreted as IRC commands.
func (c *Connection) Send(target, message string) error {
	// Handle IRC commands (messages starting with /) — some commands like
	// /connect and /reconnect must work even when disconnected.
	if strings.HasPrefix(message, "/") {
		return c.handleCommand(target, message[1:])
	}

	c.mu.RLock()
	if c.State() != core.StateConnected || c.client == nil {
		c.mu.RUnlock()
		return ErrNotConnected
	}
	c.mu.RUnlock()

	if target == "" {
		return ErrNoTarget
	}

	// Allow "NickServ: identify password" style shorthand: strip the service
	// account prefix and redirect to that target.
	if profile := c.Profile(); profile != nil {
		target, message = applyServiceAccountPrefix(profile.ServiceAccounts(), target, message)
	}

	var messages []string
	if profile := c.Profile(); profile != nil {
		messages = profile.SplitMessage(message)
	} else {
		// Fallback if no profile (shouldn't happen in normal operation)
		messages = []string{message}
	}

	for _, msg := range messages {
		if err := c.client.Privmsg(target, msg); err != nil {
			return err
		}
	}

	c.emitSentMessage(target, message, "private")
	return nil
}

// SetNick sets the current nickname.
func (c *Connection) SetNick(nick string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.nick = nick
}

// reconnectLoop attempts to reconnect with exponential backoff.
func (c *Connection) reconnectLoop() {
	const (
		minDelay = 2 * time.Second
		maxDelay = 5 * time.Minute
	)

	c.mu.Lock()
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
	c.mu.Unlock()

	c.emitState("queued", fmt.Sprintf("Reconnecting in %s.", delay.Truncate(time.Second)))

	select {
	case <-time.After(delay):
		// Continue to reconnect
	case <-stop:
		return
	}

	if c.WantedState() != core.StateConnected {
		return
	}

	if err := c.Connect(); err != nil {
		// Connect failed immediately; the disconnect callback will fire another reconnectLoop
		return
	}
}

// openConversation creates (or retrieves) a private conversation and emits a
// frozen-state event so the frontend adds it to the sidebar.
func (c *Connection) openConversation(nick string) error {
	convID := strings.ToLower(nick)
	conv := c.GetConversation(convID)
	if conv == nil {
		conv = core.NewConversation(convID, c)
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
	return nil
}

// saveState persists the connection (including conversations) to the backend.
func (c *Connection) saveState() {
	if err := c.User().Core().Backend().SaveConnection(c); err != nil {
		c.User().Core().Events().EmitUser(c.User().ID(), map[string]any{
			"event":         "state",
			"type":          "connection",
			"connection_id": c.ID(),
			"message":       "Failed to save connection state: " + err.Error(),
		})
	}
}

// emitSentMessage emits a message event for a message the user sent,
// so the frontend can display it. IRC servers don't echo your own messages back.
func (c *Connection) emitSentMessage(target, message, msgType string) {
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

	c.persistMessage(convID, from, message, msgType, false, time.Now().Unix(), "", "", "")
}

// persistMessage saves a message to the backend storage.
func (c *Connection) persistMessage(convID, from, message, msgType string, highlight bool, ts int64, msgID, account, replyTo string) {
	conv := c.GetConversation(convID)
	if conv == nil {
		slog.Warn("Conversation not found for message", "conversation_id", convID)
		return
	}

	msg := core.Message{
		From:      from,
		Message:   message,
		Type:      msgType,
		Highlight: highlight,
		Timestamp: ts,
		MsgID:     msgID,
		Account:   account,
		ReplyTo:   replyTo,
	}

	err := c.User().Core().Backend().SaveMessage(conv, msg)
	if err != nil {
		slog.Error("Failed to save message", "conversation_id", convID, "error", err)
	}
}

// emitEvent emits an event to the user's event subscribers.
func (c *Connection) emitEvent(event map[string]any) {
	event["connection_id"] = c.ID()
	c.User().Core().Events().EmitUser(c.User().ID(), event)
}

// emitState emits a connection state change event.
func (c *Connection) emitState(state, message string) {
	c.emitEvent(map[string]any{
		"event":   "state",
		"type":    "connection",
		"state":   state,
		"message": message,
	})
}

// emitInfo emits the connection info (nick, server details).
func (c *Connection) emitInfo() {
	c.mu.RLock()
	nick := c.nick
	c.mu.RUnlock()

	baseInfo := c.Info()
	info := map[string]any{
		"event": "state",
		"type":  "info",
		"nick":  nick,
	}
	maps.Copy(info, baseInfo)
	c.emitEvent(info)
}

// isHighlight checks if a message should be highlighted for this user.
func (c *Connection) isHighlight(message string) bool {
	currentNick := c.Nick()
	if currentNick != "" && strings.Contains(strings.ToLower(message), strings.ToLower(currentNick)) {
		return true
	}

	keywords := c.User().HighlightKeywords()
	lowerMsg := strings.ToLower(message)
	for _, kw := range keywords {
		if kw != "" && strings.Contains(lowerMsg, strings.ToLower(kw)) {
			return true
		}
	}

	return false
}

// getOrCreateConv returns the conversation for convID, creating it if needed.
// When isServiceAccount is true the look-up falls back to the server-log
// conversation (empty ID) instead of creating a new one.
func (c *Connection) getOrCreateConv(convID string, isServiceAccount bool) *core.Conversation {
	if conv := c.GetConversation(convID); conv != nil {
		return conv
	}
	if isServiceAccount {
		if conv := c.GetConversation(""); conv != nil {
			return conv
		}
		conv := core.NewConversationWithID("", c.Name(), c)
		c.AddConversation(conv)
		return conv
	}
	var conv *core.Conversation
	if convID == "" {
		conv = core.NewConversationWithID("", c.Name(), c)
	} else {
		conv = core.NewConversation(convID, c)
	}
	c.AddConversation(conv)
	return conv
}

// EnsureConversation finds or creates a conversation for a given target and sender.
// It handles private message redirection (target == self), wildcard target (server log),
// and service account redirection.
func (c *Connection) EnsureConversation(target, sender string) *core.Conversation {
	convID := target
	if target == "*" {
		convID = ""
	} else if target == c.Nick() {
		// Private message - use sender's nick as conversation ID
		convID = sender
	}

	// Service accounts (e.g. NickServ, ChanServ) are routed to an existing
	// conversation if one is open, otherwise they fall back to the server log.
	profile := c.Profile()
	isServiceAccount := profile != nil && profile.FindServiceAccount(sender, target) != ""
	return c.getOrCreateConv(convID, isServiceAccount)
}

// applyServiceAccountPrefix checks whether message starts with "sa: " for any
// configured service account name (case-insensitive). If it does, the prefix
// is stripped and target is replaced with the matching service account name.
func applyServiceAccountPrefix(serviceAccounts []string, target, message string) (string, string) {
	lower := strings.ToLower(message)
	for _, sa := range serviceAccounts {
		prefix := strings.ToLower(sa) + ":"
		if strings.HasPrefix(lower, prefix) && len(message) > len(prefix) {
			rest := message[len(prefix):]
			if rest[0] == ' ' || rest[0] == '\t' {
				return sa, strings.TrimLeft(rest, " \t")
			}
		}
	}
	return target, message
}

// Ensure Connection implements core.Connection interface.
var _ core.Connection = (*Connection)(nil)
