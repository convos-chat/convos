package core

import (
	"net/url"
	"strconv"
	"strings"
	"sync"
)

// ConnectionProfile represents default settings for a connection.
type ConnectionProfile struct {
	mu                 sync.RWMutex
	core               *Core
	id                 string
	isDefault          bool
	isForced           bool
	maxBulkMessageSize int
	maxMessageLength   int
	serviceAccounts    []string
	skipQueue          bool
	url                *url.URL
	webircPassword     string
}

// NewConnectionProfile creates a new connection profile.
func NewConnectionProfile(rawURL string, core *Core) *ConnectionProfile {
	u, _ := url.Parse(rawURL)
	p := &ConnectionProfile{
		core:               core,
		url:                u,
		maxBulkMessageSize: 3,
		maxMessageLength:   512,
		serviceAccounts:    []string{"chanserv", "nickserv"},
	}

	// Load defaults from environment
	p.LoadEnv()

	if u != nil && u.Host == "localhost" {
		p.skipQueue = true
	}

	return p
}

// LoadEnv loads configuration from environment variables.
func (p *ConnectionProfile) LoadEnv() {
	p.mu.Lock()
	defer p.mu.Unlock()

	if val := p.core.getenv("CONVOS_MAX_BULK_MESSAGE_SIZE"); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			p.maxBulkMessageSize = i
		}
	}
	if val := p.core.getenv("CONVOS_MAX_MESSAGE_LENGTH"); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			p.maxMessageLength = i
		}
	}
	if val := p.core.getenv("CONVOS_SERVICE_ACCOUNTS"); val != "" {
		p.serviceAccounts = strings.Split(val, ",")
	}
}

// ApplyDefaults copies settings from another profile.
func (p *ConnectionProfile) ApplyDefaults(other *ConnectionProfile) {
	p.mu.Lock()
	defer p.mu.Unlock()
	other.mu.RLock()
	defer other.mu.RUnlock()

	p.maxBulkMessageSize = other.maxBulkMessageSize
	p.maxMessageLength = other.maxMessageLength
	p.serviceAccounts = make([]string, len(other.serviceAccounts))
	copy(p.serviceAccounts, other.serviceAccounts)
}

// ID returns the unique identifier for this profile.
func (p *ConnectionProfile) ID() string {
	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.id != "" {
		return p.id
	}

	if p.url != nil {
		p.id = strings.ToLower(p.url.Scheme + "-" + prettyConnectionName(p.url.Host))
	}
	return p.id
}

// MaxBulkMessageSize returns the max number of lines before a message is considered too long.
func (p *ConnectionProfile) MaxBulkMessageSize() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.maxBulkMessageSize
}

// MaxMessageLength returns the max number of characters in a single message.
func (p *ConnectionProfile) MaxMessageLength() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.maxMessageLength
}

// ServiceAccounts returns the list of service accounts for this connection.
func (p *ConnectionProfile) ServiceAccounts() []string {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.serviceAccounts
}

// WebircPassword returns the password used for WEBIRC.
func (p *ConnectionProfile) WebircPassword() string {
	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.webircPassword != "" {
		return p.webircPassword
	}

	// Try environment variable: CONVOS_WEBIRC_PASSWORD_<HOST_PART>
	if p.url != nil {
		hostPart := strings.ToUpper(prettyConnectionName(p.url.Host))
		return p.core.getenv("CONVOS_WEBIRC_PASSWORD_" + hostPart)
	}

	return ""
}

// FindServiceAccount checks if a nick is a known service account.
func (p *ConnectionProfile) FindServiceAccount(nicks ...string) string {
	p.mu.RLock()
	defer p.mu.RUnlock()

	for _, nick := range nicks {
		lnick := strings.ToLower(nick)
		for _, sa := range p.serviceAccounts {
			if strings.ToLower(sa) == lnick {
				return nick
			}
		}
	}
	return ""
}

// ToData converts the profile to a serializable format.
func (p *ConnectionProfile) ToData() ConnectionProfileData {
	p.mu.RLock()
	defer p.mu.RUnlock()

	data := ConnectionProfileData{
		ID:                 p.ID(),
		IsDefault:          p.isDefault,
		IsForced:           p.isForced,
		MaxBulkMessageSize: p.maxBulkMessageSize,
		MaxMessageLength:   p.maxMessageLength,
		ServiceAccounts:    p.serviceAccounts,
		SkipQueue:          p.skipQueue,
		WebircPassword:     p.WebircPassword(),
	}

	if p.url != nil {
		data.URL = p.url.String()
	}

	return data
}

// FromData loads the profile from a serializable format.
func (p *ConnectionProfile) FromData(data ConnectionProfileData) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.id = data.ID
	p.isDefault = data.IsDefault
	p.isForced = data.IsForced
	p.maxBulkMessageSize = data.MaxBulkMessageSize
	p.maxMessageLength = data.MaxMessageLength
	p.serviceAccounts = data.ServiceAccounts
	p.skipQueue = data.SkipQueue
	p.webircPassword = data.WebircPassword
	if data.URL != "" {
		p.url, _ = url.Parse(data.URL)
	}
}

// Save persists the profile to the backend.
func (p *ConnectionProfile) Save() error {
	return p.core.Backend().SaveConnectionProfile(p.ToData())
}

// SplitMessage splits a long message into multiple lines or parts based on MaxMessageLength.
func (p *ConnectionProfile) SplitMessage(message string) []string {
	var messages []string
	lines := strings.Split(message, "\n")

	for _, line := range lines {
		line = strings.TrimRight(line, "\r")

		if len(line) < p.MaxMessageLength() {
			messages = append(messages, line)
			if len(messages) >= p.MaxBulkMessageSize() {
				return messages
			}
			continue
		}

		// Split long lines into multiple lines at word boundaries
		chunks := strings.FieldsFunc(line, func(r rune) bool {
			return r == ' ' || r == '\t'
		})

		currentLine := ""
		for _, chunk := range chunks {
			if len(chunk) > p.MaxMessageLength() {
				// Force break if chunk itself is too long
				if currentLine != "" {
					messages = append(messages, strings.TrimSpace(currentLine))
					if len(messages) >= p.MaxBulkMessageSize() {
						return messages
					}
				}
				for len(chunk) > p.MaxMessageLength() {
					messages = append(messages, chunk[:p.MaxMessageLength()-1])
					if len(messages) >= p.MaxBulkMessageSize() {
						return messages
					}
					chunk = chunk[p.MaxMessageLength()-1:]
				}
				currentLine = chunk
				continue
			}

			if len(currentLine)+len(chunk)+1 > p.MaxMessageLength() {
				messages = append(messages, strings.TrimSpace(currentLine))
				if len(messages) >= p.MaxBulkMessageSize() {
					return messages
				}
				currentLine = chunk
			} else {
				if currentLine == "" {
					currentLine = chunk
				} else {
					currentLine += " " + chunk
				}
			}
		}
		if currentLine != "" {
			messages = append(messages, strings.TrimSpace(currentLine))
			if len(messages) >= p.MaxBulkMessageSize() {
				return messages
			}
		}
	}

	return messages
}

// TooLongMessages returns true if the slice of messages violates bulk size or length limits.
func (p *ConnectionProfile) TooLongMessages(messages []string) bool {
	if len(messages) >= p.MaxBulkMessageSize() {
		return true
	}
	for _, msg := range messages {
		if len(msg) >= p.MaxMessageLength() {
			return true
		}
	}
	return false
}
