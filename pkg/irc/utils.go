package irc

import (
	"strings"
	"time"

	"github.com/ergochat/irc-go/ircmsg"
)

// parseServerTime extracts the server-time tag from an IRC message.
// Always returns UTC so callers produce "Z"-suffixed RFC3339 strings.
func parseServerTime(msg ircmsg.Message) time.Time {
	if present, value := msg.GetTag("time"); present {
		if t, err := time.Parse(time.RFC3339Nano, value); err == nil {
			return t.UTC()
		}
	}
	return time.Now().UTC()
}

// serverTimeOrNow extracts the server-time tag from an IRC message.
// Returns the parsed time as Unix seconds, or time.Now().Unix() as fallback.
func serverTimeOrNow(msg ircmsg.Message) int64 {
	return parseServerTime(msg).Unix()
}

// serverTimeOrNowRFC3339 extracts the server-time tag from an IRC message.
// Returns the time formatted as RFC3339, or the current time as fallback.
func serverTimeOrNowRFC3339(msg ircmsg.Message) string {
	return parseServerTime(msg).Format(time.RFC3339)
}

// parseNickMode extracts all mode prefixes and the nick from an IRC NAMES entry.
// Supports multi-prefix (multiple consecutive prefixes, e.g. "@+nick" → "ov", "nick").
// Mode prefixes: ~ = q (founder), & = a (admin), @ = o (operator),
// % = h (half-op), + = v (voice).
func parseNickMode(raw string) (string, string) {
	var modes strings.Builder
	for i := range len(raw) {
		switch raw[i] {
		case '~':
			modes.WriteByte('q')
		case '&':
			modes.WriteByte('a')
		case '@':
			modes.WriteByte('o')
		case '%':
			modes.WriteByte('h')
		case '+':
			modes.WriteByte('v')
		default:
			return modes.String(), raw[i:]
		}
	}
	return modes.String(), ""
}

// parseNamesEntry parses a single token from a NAMES reply, handling:
//   - multi-prefix: multiple mode chars before the nick (e.g. "@+nick" → modes="ov")
//   - userhost-in-names: user@host appended to nick (e.g. "nick!user@host")
func parseNamesEntry(raw string) (string, string, string, string) {
	mode, rest := parseNickMode(raw)
	nick, userhost, _ := strings.Cut(rest, "!")
	user, host, _ := strings.Cut(userhost, "@")
	return mode, nick, user, host
}
