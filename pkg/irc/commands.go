package irc

import (
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/core"
)

var (
	ErrUsageJoin          = errors.New("usage: /join #channel")
	ErrUsagePart          = errors.New("usage: /part #channel")
	ErrUsageMsg           = errors.New("usage: /msg target message")
	ErrUsageNick          = errors.New("usage: /nick newnick")
	ErrUsageKick          = errors.New("usage: /kick nick [reason]")
	ErrUsageMe            = errors.New("usage: /me action")
	ErrUsageSay           = errors.New("usage: /say message")
	ErrUsageWhois         = errors.New("usage: /whois nick")
	ErrUsageQuery         = errors.New("usage: /query <nick> [message]")
	ErrUsageNames         = errors.New("usage: /names #channel")
	ErrUsageInvite        = errors.New("usage: /invite nick [#channel]")
	ErrUsageInviteChannel = errors.New("usage: /invite nick #channel")
	ErrUsageOper          = errors.New("usage: /oper user password")
	ErrUsageClear         = errors.New("WARNING: /clear history <name> will delete all messages in the backend")
	ErrUsageIson          = errors.New("usage: /ison nick")
	// ErrUsageUnignore is returned when /unignore is called without a nick.
	// There is no paired ErrUsageIgnore because bare /ignore (no args) is valid: it lists masks.
	ErrUsageUnignore    = errors.New("usage: /unignore <nick>")
	ErrCannotIgnoreSelf = errors.New("cannot ignore yourself")
	ErrNotIgnored       = errors.New("nick is not in ignore list")
)

// handleCommand parses and executes an IRC command from user input.
func (c *Connection) handleCommand(target, raw string, requestID any) error {
	parts := strings.SplitN(raw, " ", 2)
	command := strings.ToUpper(parts[0])
	args := ""
	if len(parts) > 1 {
		args = parts[1]
	}

	// Commands that work regardless of connection state.
	switch command {
	case "CONNECT":
		c.SetWantedState(core.StateConnected)
		go func() {
			if err := c.Connect(); err != nil {
				c.LogServerError(fmt.Sprintf("Failed to connect to %s: %s", c.URL().Host, err))
			}
		}()
		return nil
	case "DISCONNECT":
		c.SetWantedState(core.StateDisconnected)
		go func() {
			if err := c.Disconnect(); err != nil {
				c.LogServerError(fmt.Sprintf("Failed to disconnect from %s: %s", c.URL().Host, err))
			}
		}()
		return nil
	case "RECONNECT":
		go func() {
			if err := c.Disconnect(); err != nil {
				c.LogServerError(fmt.Sprintf("Failed to disconnect from %s: %s", c.URL().Host, err))
			}
			if err := c.Connect(); err != nil {
				c.LogServerError(fmt.Sprintf("Failed to reconnect to %s: %s", c.URL().Host, err))
			}
		}()
		return nil
	case "PART", "LEAVE", "CLOSE":
		ch := target
		if args != "" {
			ch = strings.SplitN(args, " ", 2)[0]
		}
		if ch == "" {
			return ErrUsagePart
		}
		// For private conversations, frozen conversations, or when disconnected,
		// just remove locally — there's no channel to PART from on the server.
		conv := c.GetConversation(ch)
		if conv != nil && (conv.IsPrivate() || conv.Frozen() != "") || c.State() != core.StateConnected {
			c.RemoveConversation(ch)
			c.saveState()
			c.emitEvent(&core.StatePartEvent{
				ConversationID: strings.ToLower(ch),
				Nick:           c.Nick(),
			})
			return nil
		}
		return c.client.Part(ch)
	case "CLEAR":
		clearParts := strings.Fields(args)
		if len(clearParts) < 2 || clearParts[0] != "history" {
			return ErrUsageClear
		}
		convTarget := clearParts[1]
		conv := c.GetConversation(convTarget)
		if conv == nil {
			return ErrUnknownConversation
		}
		if err := c.User().Core.Backend.DeleteMessages(conv); err != nil {
			return err
		}
		c.emitEvent(&core.SentEvent{
			ConversationID: conv.ID(),
			Command:        []string{"clear"},
		})
		return nil
	case "QUERY":
		qparts := strings.Fields(args)
		if len(qparts) == 0 {
			return ErrUsageQuery
		}
		if err := c.openConversation(qparts[0]); err != nil {
			return err
		}
		if len(qparts) > 1 {
			return c.Send(qparts[0], strings.Join(qparts[1:], " "), nil)
		}
		return nil
	case "IGNORE":
		nick := strings.TrimSpace(args)
		if nick == "" {
			// List ignores
			masks := c.User().IgnoreMasks()
			c.emitEvent(&core.SentEvent{
				ConversationID: target,
				Message:        "/ignore",
				Command:        []string{"ignore"},
				Data:           map[string]any{"masks": masks},
			})
			return nil
		}
		// Guard: cannot ignore self
		if strings.EqualFold(nick, c.Nick()) {
			return ErrCannotIgnoreSelf
		}
		// Need active connection for WHOIS
		c.mu.RLock()
		connected := c.State() == core.StateConnected && c.client != nil
		c.mu.RUnlock()
		if !connected {
			return ErrNotConnected
		}
		// Store waiter and trigger WHOIS
		c.mu.Lock()
		c.ignoreWaiters[strings.ToLower(nick)] = nick
		c.mu.Unlock()
		return c.client.Send("WHOIS", nick)
	case "UNIGNORE":
		nick := strings.TrimSpace(args)
		if nick == "" {
			return ErrUsageUnignore
		}
		// Case-insensitive lookup: IRC nicks are case-insensitive, so "/unignore
		// badnick" should match a key stored as "BadNick".
		masks := c.User().IgnoreMasks()
		var storedKey string
		for k := range masks {
			if strings.EqualFold(k, nick) {
				storedKey = k
				break
			}
		}
		if storedKey == "" {
			return ErrNotIgnored
		}
		c.User().RemoveIgnoreMask(storedKey)
		if err := c.User().Save(); err != nil {
			return err
		}
		c.emitEvent(&core.SentEvent{
			ConversationID: target,
			Message:        "/unignore",
			Command:        []string{"unignore"},
			Data:           map[string]any{"nick": nick},
		})
		return nil
	}

	// Remaining commands require an active connection.
	c.mu.RLock()
	connected := c.State() == core.StateConnected && c.client != nil
	c.mu.RUnlock()
	if !connected {
		return ErrNotConnected
	}

	switch command {
	case "JOIN", "J":
		if args == "" {
			return ErrUsageJoin
		}
		ch := strings.SplitN(args, " ", 2)[0]
		if !core.ChannelRE.MatchString(ch) {
			return c.openConversation(ch)
		}
		return c.client.Join(ch)
	case "MSG":
		msgParts := strings.SplitN(args, " ", 2)
		if len(msgParts) < 2 {
			return ErrUsageMsg
		}
		if err := c.client.Privmsg(msgParts[0], msgParts[1]); err != nil {
			return err
		}
		c.emitSentMessage(msgParts[0], msgParts[1], core.MessageTypePrivate)
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
		// /mode with no args → query mode of current target.
		// Register the waiter before sending to avoid a race with a fast response.
		if target != "" {
			ch := strings.ToLower(target)
			c.mu.Lock()
			c.modeWaiters[ch] = requestID
			c.mu.Unlock()
			if err := c.client.Send("MODE", target); err != nil {
				c.mu.Lock()
				delete(c.modeWaiters, ch)
				c.mu.Unlock()
				return err
			}
			return nil
		}
		return nil
	case "ME":
		if target == "" || args == "" {
			return ErrUsageMe
		}
		if err := c.client.Privmsg(target, "\x01ACTION "+args+"\x01"); err != nil {
			return err
		}
		c.emitSentMessage(target, args, core.MessageTypeAction)
		return nil
	case "SAY":
		if target == "" || args == "" {
			return ErrUsageSay
		}
		if err := c.client.Privmsg(target, args); err != nil {
			return err
		}
		c.emitSentMessage(target, args, core.MessageTypePrivate)
		return nil
	case "ISON":
		if args == "" {
			return ErrUsageIson
		}
		return c.client.Send("ISON", args)
	case "WHOIS":
		nick := args
		if nick == "" {
			return ErrUsageWhois
		}
		return c.client.Send("WHOIS", nick)
	case "NAMES":
		ch := target
		if args != "" {
			ch = args
		}
		if ch == "" {
			return ErrUsageNames
		}
		ch = strings.ToLower(ch)
		// Register before sending to avoid a race with a fast IRC response.
		c.mu.Lock()
		c.namesWaiters[ch] = requestID
		c.mu.Unlock()
		if err := c.client.Send("NAMES", ch); err != nil {
			c.mu.Lock()
			delete(c.namesWaiters, ch)
			c.mu.Unlock()
			return err
		}
		return nil
	case "INVITE":
		inviteParts := strings.Fields(args)
		if len(inviteParts) == 0 || inviteParts[0] == "" {
			return ErrUsageInvite
		}
		ch := target
		if len(inviteParts) > 1 {
			ch = inviteParts[1]
		}
		if ch == "" {
			return ErrUsageInviteChannel
		}
		return c.client.Send("INVITE", inviteParts[0], ch)
	case "AWAY":
		if args == "" {
			return c.client.Send("AWAY")
		}
		return c.client.Send("AWAY", args)
	case "OPER":
		if args == "" {
			return ErrUsageOper
		}
		return c.client.SendRaw("OPER " + args)
	case "LIST":
		return c.handleListCommand(target, args, requestID)
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

// executeCommand runs an on-connect command (e.g., /join #channel, /msg NickServ ...).
func (c *Connection) executeCommand(cmd string) {
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

// handleListCommand implements the /list command with caching and search.
// Usage: /list [refresh] [/pattern/[flags]]
//
// Always emits a SentEvent with the current cache state immediately (matching
// Perl's _send_list_p behaviour). When the cache is empty or "refresh" is
// requested, it also triggers a fresh IRC LIST fetch so results trickle in
// asynchronously via handleListReply / handleListEnd events.
//
// With no args: emits cached results (or fetches if no cache).
// "refresh": clears cache and re-fetches from server.
// /pattern/: searches cached channels by name and topic (case-insensitive).
// /pattern/n: search by name only. /pattern/t: search by topic only.
func (c *Connection) handleListCommand(target, args string, requestID any) error {
	c.mu.Lock()

	// Refresh if requested or no cache exists — fire off the IRC LIST but
	// still fall through and emit the (empty) cache immediately.
	if strings.Contains(args, "refresh") || c.listBuf.ts.IsZero() {
		c.listBuf = listCache{
			conversations: make(map[string]listEntry),
			ts:            time.Now(),
		}
		c.mu.Unlock()
		if err := c.client.Send("LIST"); err != nil {
			return err
		}
		data := map[string]any{
			"conversations":   []map[string]any{},
			"n_conversations": 0,
			"done":            false,
		}
		if requestID != nil {
			data["id"] = requestID
		}
		c.emitEvent(&core.SentEvent{
			ConversationID: target,
			Message:        "/list",
			Command:        []string{"list"},
			Data:           data,
		})
		return nil
	}

	// Snapshot the cache under lock
	entries := make([]listEntry, 0, len(c.listBuf.conversations))
	for _, e := range c.listBuf.conversations {
		entries = append(entries, e)
	}
	done := c.listBuf.done
	total := len(c.listBuf.conversations)
	c.mu.Unlock()

	found := c.filterListEntries(entries, args)

	// Cap at 200 results
	if len(found) > 200 {
		found = found[:200]
	}

	convList := make([]map[string]any, len(found))
	for i, e := range found {
		convList[i] = map[string]any{
			"name":            e.Name,
			"conversation_id": e.ConversationID,
			"n_users":         e.NUsers,
			"topic":           e.Topic,
		}
	}

	data := map[string]any{
		"conversations":   convList,
		"n_conversations": total,
		"done":            done,
	}
	if requestID != nil {
		data["id"] = requestID
	}
	c.emitEvent(&core.SentEvent{
		ConversationID: target,
		Message:        "/list",
		Command:        []string{"list"},
		Data:           data,
	})
	return nil
}

// listFilterRE matches /pattern/[modifiers] in /list arguments.
var listFilterRE = regexp.MustCompile(`/(\W?[\w-]+)/(\S*)`)

// filterListEntries searches or sorts cached LIST entries based on args.
func (c *Connection) filterListEntries(entries []listEntry, args string) []listEntry {
	m := listFilterRE.FindStringSubmatch(args)
	if m == nil {
		// No search — return all, sorted by user count descending
		sort.Slice(entries, func(i, j int) bool {
			return entries[i].NUsers > entries[j].NUsers
		})
		return entries
	}

	pattern := m[1]
	modifiers := m[2]

	// Determine search scope: n=name, t=topic, default=both
	byName, byTopic := true, true
	if strings.Contains(modifiers, "n") {
		byTopic = false
	} else if strings.Contains(modifiers, "t") {
		byName = false
	}

	re, err := regexp.Compile("(?i)" + regexp.QuoteMeta(pattern))
	if err != nil {
		return nil
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name < entries[j].Name
	})

	var nameMatches, topicMatches []listEntry
	for _, e := range entries {
		if byName && re.MatchString(e.Name) {
			nameMatches = append(nameMatches, e)
		} else if byTopic && re.MatchString(e.Topic) {
			topicMatches = append(topicMatches, e)
		}
	}
	return append(nameMatches, topicMatches...)
}
