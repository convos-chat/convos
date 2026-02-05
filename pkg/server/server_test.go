package server

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"

	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
)

func TestSPAHandler(t *testing.T) {
	t.Parallel()
	c := core.New(core.WithBackend(core.NewMemoryBackend()))
	cfg := &config.Config{SessionSecret: "secret"}
	s := New(c, cfg)

	t.Run("ServeIndex", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequest("GET", "/", nil)
		w := httptest.NewRecorder()
		s.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("Expected 200, got %d", w.Code)
		}

		body := w.Body.String()
		if !strings.Contains(body, "Starting Convos...") {
			t.Error("Body does not contain loading indicator")
		}
		re := regexp.MustCompile(`<script src="\/assets\/convos\.\w+\.js"><\/script>`)
		if !re.MatchString(body) {
			t.Errorf("Body does not contain expected JS asset: %s", body)
		}
	})
}

func TestRequireAuthMiddleware(t *testing.T) {
	t.Parallel()
	s, _ := setupServer()

	tests := []struct {
		name           string
		method         string
		path           string
		expectedStatus int
	}{
		{"Public login", "POST", "/api/user/login", http.StatusBadRequest}, // 400 because empty body
		{"Public register", "POST", "/api/user/register", http.StatusBadRequest},
		{"Private settings", "GET", "/api/settings", http.StatusUnauthorized},
		{"Private user", "GET", "/api/user", http.StatusUnauthorized},
		{"Private connections", "GET", "/api/connections", http.StatusUnauthorized},
		{"Public OpenAPI", "GET", "/api", http.StatusOK},
		{"Public i18n", "GET", "/api/i18n/en", http.StatusOK},
	}

	for i, tt := range tests {
		tt := tt
		remoteAddr := fmt.Sprintf("192.0.2.%d:1234", i+1)
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			req := httptest.NewRequest(tt.method, tt.path, nil)
			req.RemoteAddr = remoteAddr
			w := httptest.NewRecorder()
			s.ServeHTTP(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("%s: expected status %d, got %d", tt.path, tt.expectedStatus, w.Code)
			}
		})
	}
}

func setupServer() (*Server, *core.Core) {
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	falseVal := false
	cfg := &config.Config{
		SessionSecret: "test-secret",
		SecureCookies: &falseVal,
	}
	s := New(c, cfg)
	return s, c
}

func loginUser(t *testing.T, s *Server, c *core.Core, email, password string) *http.Cookie {
	t.Helper()

	// Create user if not exists (backend save + in-memory map)
	u, _ := c.User(email)
	_ = u.SetPassword(password)
	_ = u.Save()

	// Login via API to get cookie
	body := map[string]string{
		"email":    email,
		"password": password,
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest("POST", "/api/user/login", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Login helper failed: %d %s", w.Code, w.Body.String())
	}

	for _, cookie := range w.Result().Cookies() {
		if cookie.Name == "convos" {
			return cookie
		}
	}
	t.Fatal("Session cookie not found in login helper")
	return nil
}
