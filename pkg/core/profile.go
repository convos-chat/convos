package core

import (
	"net/url"
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
		core:           core,
		url:            u,
		webircPassword: "",
	}

	if u != nil && u.Host == "localhost" {
		p.skipQueue = true
	}
	p.loadDefaults()

	return p
}

// LoadEnv loads configuration from environment variables.
func (p *ConnectionProfile) loadDefaults() {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.core.DefaultMaxBulkMessageSize > 0 {
		p.maxBulkMessageSize = p.core.DefaultMaxBulkMessageSize
	}
	if p.core.DefaultMaxMessageLength > 0 {
		p.maxMessageLength = p.core.DefaultMaxMessageLength
	}
	if len(p.core.DefaultServiceAccounts) != 0 {
		p.serviceAccounts = p.core.DefaultServiceAccounts
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
		p.id = strings.ToLower(p.url.Scheme + "-" + PrettyConnectionName(p.url.Host))
	}
	return p.id
}

// SetIsDefault sets whether this is the default profile.
func (p *ConnectionProfile) SetIsDefault(v bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.isDefault = v
}

// IsDefault returns whether this is the default profile.
func (p *ConnectionProfile) IsDefault() bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.isDefault
}

// SetSkipQueue sets whether to skip the connection queue.
func (p *ConnectionProfile) SetSkipQueue(v bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.skipQueue = v
}

// SkipQueue returns whether to skip the connection queue.
func (p *ConnectionProfile) SkipQueue() bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.skipQueue
}

// MaxBulkMessageSize returns the max number of lines before a message is considered too long.
func (p *ConnectionProfile) MaxBulkMessageSize() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.maxBulkMessageSize
}

// SetMaxBulkMessageSize sets the max number of lines before a message is considered too long.
func (p *ConnectionProfile) SetMaxBulkMessageSize(v int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.maxBulkMessageSize = v
}

// MaxMessageLength returns the max number of characters in a single message.
func (p *ConnectionProfile) MaxMessageLength() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.maxMessageLength
}

// SetMaxMessageLength sets the max number of characters in a single message.
func (p *ConnectionProfile) SetMaxMessageLength(v int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.maxMessageLength = v
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
