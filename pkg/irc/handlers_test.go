package irc

import (
	"testing"
	"time"

	"github.com/ergochat/irc-go/ircmsg"
)

func TestApplyServiceAccountPrefix(t *testing.T) {
	t.Parallel()

	sas := []string{"nickserv", "chanserv"}

	tests := []struct {
		target      string
		message     string
		wantTarget  string
		wantMessage string
	}{
		{"#chan", "nickserv: identify pass", "nickserv", "identify pass"},
		{"#chan", "NickServ: identify pass", "nickserv", "identify pass"},
		{"#chan", "CHANSERV: op #chan", "chanserv", "op #chan"},
		{"#chan", "nickserv:nospace", "#chan", "nickserv:nospace"}, // no whitespace after colon
		{"#chan", "hello world", "#chan", "hello world"},
		{"#chan", "nickserv:", "#chan", "nickserv:"}, // nothing after colon
	}

	for _, tt := range tests {
		gotTarget, gotMsg := applyServiceAccountPrefix(sas, tt.target, tt.message)
		if gotTarget != tt.wantTarget || gotMsg != tt.wantMessage {
			t.Errorf("applyServiceAccountPrefix(%q, %q) = (%q, %q), want (%q, %q)",
				tt.target, tt.message, gotTarget, gotMsg, tt.wantTarget, tt.wantMessage)
		}
	}
}

func TestServerTimeOrNow(t *testing.T) {
	t.Parallel()

	t.Run("valid time tag", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(map[string]string{
			"time": "2024-06-15T12:30:45.000Z",
		}, "nick!user@host", "PRIVMSG", "#test", "hello")
		got := serverTimeOrNow(msg)
		want := time.Date(2024, 6, 15, 12, 30, 45, 0, time.UTC).Unix()
		if got != want {
			t.Errorf("serverTimeOrNow() = %d, want %d", got, want)
		}
	})

	t.Run("valid time tag without millis", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(map[string]string{
			"time": "2024-06-15T12:30:45Z",
		}, "nick!user@host", "PRIVMSG", "#test", "hello")
		got := serverTimeOrNow(msg)
		want := time.Date(2024, 6, 15, 12, 30, 45, 0, time.UTC).Unix()
		if got != want {
			t.Errorf("serverTimeOrNow() = %d, want %d", got, want)
		}
	})

	t.Run("invalid time tag falls back to now", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(map[string]string{
			"time": "not-a-timestamp",
		}, "nick!user@host", "PRIVMSG", "#test", "hello")
		before := time.Now().Unix()
		got := serverTimeOrNow(msg)
		after := time.Now().Unix()
		if got < before || got > after {
			t.Errorf("serverTimeOrNow() = %d, want between %d and %d", got, before, after)
		}
	})

	t.Run("no time tag falls back to now", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(nil, "nick!user@host", "PRIVMSG", "#test", "hello")
		before := time.Now().Unix()
		got := serverTimeOrNow(msg)
		after := time.Now().Unix()
		if got < before || got > after {
			t.Errorf("serverTimeOrNow() = %d, want between %d and %d", got, before, after)
		}
	})
}

func TestServerTimeOrNowRFC3339(t *testing.T) {
	t.Parallel()

	t.Run("valid time tag", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(map[string]string{
			"time": "2024-06-15T12:30:45.123Z",
		}, "nick!user@host", "PRIVMSG", "#test", "hello")
		got := serverTimeOrNowRFC3339(msg)
		want := "2024-06-15T12:30:45Z"
		if got != want {
			t.Errorf("serverTimeOrNowRFC3339() = %q, want %q", got, want)
		}
	})

	t.Run("no time tag falls back to now", func(t *testing.T) {
		t.Parallel()
		msg := ircmsg.MakeMessage(nil, "nick!user@host", "PRIVMSG", "#test", "hello")
		got := serverTimeOrNowRFC3339(msg)
		if _, err := time.Parse(time.RFC3339, got); err != nil {
			t.Errorf("serverTimeOrNowRFC3339() = %q, not valid RFC3339: %v", got, err)
		}
	})
}
