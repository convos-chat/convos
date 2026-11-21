package irc

import (
	"testing"
	"time"

	"github.com/ergochat/irc-go/ircmsg"
)

func TestIsErrorCommand(t *testing.T) {
	t.Parallel()

	tests := []struct {
		command string
		want    bool
	}{
		{"468", true},  // ERR_INVALIDUSERNAME
		{"432", true},  // ERR_ERRONEUSNICKNAME
		{"400", true},  // start of error range
		{"599", true},  // end of error range
		{"691", true},  // ERR_STARTTLS
		{"902", true},  // ERR_NICKLOCKED
		{"904", true},  // ERR_SASLFAIL
		{"907", true},  // ERR_SASLALREADY
		{"ERROR", true},
		{"001", false}, // RPL_WELCOME
		{"252", false}, // RPL_LUSEROP
		{"372", false}, // RPL_MOTD
		{"900", false}, // RPL_LOGGEDIN
		{"903", false}, // RPL_SASLSUCCESS
		{"WALLOPS", false},
	}

	for _, tt := range tests {
		t.Run(tt.command, func(t *testing.T) {
			t.Parallel()
			if got := isErrorCommand(tt.command); got != tt.want {
				t.Errorf("isErrorCommand(%q) = %v, want %v", tt.command, got, tt.want)
			}
		})
	}
}

func TestParseNickMode(t *testing.T) {
	t.Parallel()

	tests := []struct {
		input    string
		wantMode string
		wantNick string
	}{
		{"nick", "", "nick"},
		{"@nick", "o", "nick"},
		{"+nick", "v", "nick"},
		{"@+nick", "ov", "nick"},       // multi-prefix: op + voice
		{"~&@%+nick", "qaohv", "nick"}, // all prefixes
		{"", "", ""},
	}

	for _, tt := range tests {
		mode, nick := parseNickMode(tt.input)
		if mode != tt.wantMode || nick != tt.wantNick {
			t.Errorf("parseNickMode(%q) = (%q, %q), want (%q, %q)",
				tt.input, mode, nick, tt.wantMode, tt.wantNick)
		}
	}
}

func TestParseNamesEntry(t *testing.T) {
	t.Parallel()

	tests := []struct {
		input    string
		wantMode string
		wantNick string
		wantUser string
		wantHost string
	}{
		// plain nick
		{"nick", "", "nick", "", ""},
		// single prefix
		{"@nick", "o", "nick", "", ""},
		// multi-prefix (multi-prefix cap)
		{"@+nick", "ov", "nick", "", ""},
		// userhost-in-names
		{"nick!user@host.example", "", "nick", "user", "host.example"},
		// both caps together
		{"@+nick!user@host.example", "ov", "nick", "user", "host.example"},
		// empty
		{"", "", "", "", ""},
	}

	for _, tt := range tests {
		mode, nick, user, host := parseNamesEntry(tt.input)
		if mode != tt.wantMode || nick != tt.wantNick || user != tt.wantUser || host != tt.wantHost {
			t.Errorf("parseNamesEntry(%q) = (%q, %q, %q, %q), want (%q, %q, %q, %q)",
				tt.input, mode, nick, user, host,
				tt.wantMode, tt.wantNick, tt.wantUser, tt.wantHost)
		}
	}
}

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
