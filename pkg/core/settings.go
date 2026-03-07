package core

import (
	"net/url"
	"slices"
	"sync"

	"github.com/SherClockHolmes/webpush-go"
)

// Settings holds core configuration settings.
type Settings struct {
	mu                sync.RWMutex
	core              *Core
	baseURL           *url.URL
	contact           string
	defaultConnection string
	forcedConnection  bool
	localSecret       string
	openToPublic      bool
	organizationName  string
	organizationURL   string
	sessionSecrets    []string
	videoService      string
	vapidPrivateKey   string
	vapidPublicKey    string
}

// BaseURL returns the base URL for the application.
func (s *Settings) BaseURL() *url.URL {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.baseURL != nil {
		return s.baseURL
	}
	// Default
	u, _ := url.Parse("http://localhost:8080")
	return u
}

// SetBaseURL sets the base URL.
func (s *Settings) SetBaseURL(u *url.URL) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.baseURL = u
}

// OpenToPublic returns whether public registration is allowed.
func (s *Settings) OpenToPublic() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.openToPublic
}

// SetOpenToPublic sets whether public registration is allowed.
func (s *Settings) SetOpenToPublic(open bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.openToPublic = open
}

// Contact returns the contact URL/email.
func (s *Settings) Contact() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.contact
}

// SetContact sets the contact URL/email.
func (s *Settings) SetContact(contact string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.contact = contact
}

// DefaultConnection returns the default connection URL for new users.
func (s *Settings) DefaultConnection() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.defaultConnection
}

// SetDefaultConnection sets the default connection URL.
func (s *Settings) SetDefaultConnection(url string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.defaultConnection = url
}

// ForcedConnection returns whether the default connection is forced.
func (s *Settings) ForcedConnection() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.forcedConnection
}

// SetForcedConnection sets whether the default connection is forced.
func (s *Settings) SetForcedConnection(forced bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.forcedConnection = forced
}

// OrganizationName returns the organization name.
func (s *Settings) OrganizationName() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.organizationName
}

// SetOrganizationName sets the organization name.
func (s *Settings) SetOrganizationName(name string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.organizationName = name
}

// OrganizationURL returns the organization URL.
func (s *Settings) OrganizationURL() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.organizationURL
}

// SetOrganizationURL sets the organization URL.
func (s *Settings) SetOrganizationURL(url string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.organizationURL = url
}

// VideoService returns the video service URL.
func (s *Settings) VideoService() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.videoService
}

// SetVideoService sets the video service URL.
func (s *Settings) SetVideoService(url string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.videoService = url
}

// LocalSecret returns the local secret.
func (s *Settings) LocalSecret() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.localSecret
}

// SetLocalSecret sets the local secret.
func (s *Settings) SetLocalSecret(secret string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.localSecret = secret
}

// SessionSecrets returns the session secrets.
func (s *Settings) SessionSecrets() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return slices.Clone(s.sessionSecrets)
}

// SetSessionSecrets sets the session secrets.
func (s *Settings) SetSessionSecrets(secrets []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessionSecrets = secrets
}

// VAPIDKeys returns the VAPID public and private keys, generating them if necessary.
func (s *Settings) VAPIDKeys() (string, string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.vapidPublicKey != "" && s.vapidPrivateKey != "" {
		return s.vapidPublicKey, s.vapidPrivateKey, nil
	}

	privateKey, publicKey, err := webpush.GenerateVAPIDKeys()
	if err != nil {
		return "", "", err
	}

	s.vapidPrivateKey = privateKey
	s.vapidPublicKey = publicKey

	if err := s.core.Backend.SaveSettings(s.toDataLocked()); err != nil {
		return "", "", err
	}

	return publicKey, privateKey, nil
}

// ToData converts settings to a serializable format.
func (s *Settings) ToData() SettingsData {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.toDataLocked()
}

func (s *Settings) toDataLocked() SettingsData {
	data := SettingsData{
		Contact:           s.contact,
		DefaultConnection: s.defaultConnection,
		ForcedConnection:  s.forcedConnection,
		LocalSecret:       s.localSecret,
		OpenToPublic:      s.openToPublic,
		OrganizationName:  s.organizationName,
		OrganizationURL:   s.organizationURL,
		SessionSecrets:    s.sessionSecrets,
		VideoService:      s.videoService,
		VAPIDPrivateKey:   s.vapidPrivateKey,
		VAPIDPublicKey:    s.vapidPublicKey,
	}
	if s.baseURL != nil {
		data.BaseURL = s.baseURL.String()
	}
	return data
}

// FromData loads settings from a serialized format.
func (s *Settings) FromData(data SettingsData) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.contact = data.Contact
	s.defaultConnection = data.DefaultConnection
	s.forcedConnection = data.ForcedConnection
	s.localSecret = data.LocalSecret
	s.openToPublic = data.OpenToPublic
	s.organizationName = data.OrganizationName
	s.organizationURL = data.OrganizationURL
	s.sessionSecrets = data.SessionSecrets
	s.videoService = data.VideoService
	s.vapidPrivateKey = data.VAPIDPrivateKey
	s.vapidPublicKey = data.VAPIDPublicKey
	if data.BaseURL != "" {
		s.baseURL, _ = url.Parse(data.BaseURL)
	}
}

// Save persists the settings to the backend.
func (s *Settings) Save() error {
	return s.core.Backend.SaveSettings(s.ToData())
}
