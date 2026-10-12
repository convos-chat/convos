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

	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestSPAHandler(t *testing.T) {
	t.Parallel()
	c := test.NewTestCore()
	cfg := &config.Config{SessionSecret: "secret"}
	s := New(c, cfg, auth.NewLocalAuthenticator(c))

	t.Run("ServeIndex", func(t *testing.T) {
		t.Parallel()
		req := httptest.NewRequestWithContext(t.Context(), "GET", "/", nil)
		w := httptest.NewRecorder()
		s.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("Expected 200, got %d", w.Code)
		}

		body := w.Body.String()
		if !strings.Contains(body, "Starting Convos...") {
			t.Error("Body does not contain loading indicator")
		}
		re := regexp.MustCompile(`\/assets\/convos\.[\w-]+\.js"><\/script>`)
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
		remoteAddr := fmt.Sprintf("192.0.2.%d:1234", i+1)
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			req := httptest.NewRequestWithContext(t.Context(), tt.method, tt.path, nil)
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
	backend := test.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	falseVal := false
	cfg := &config.Config{
		SessionSecret: "test-secret",
		SecureCookies: &falseVal,
	}
	s := New(c, cfg, auth.NewLocalAuthenticator(c))
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
	req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", bytes.NewReader(jsonBody))
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

func TestRequestBaseURL(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name        string
		proxy       string
		requestBase string
		headers     map[string]string
		want        string
	}{
		{"Host only", "", "", nil, "http://chat.example.com"},
		{"Forwarded headers ignored without proxy", "", "", map[string]string{"X-Forwarded-Proto": "https", "X-Forwarded-Host": "evil.example.com", "X-Request-Base": "https://evil.example.com/"}, "http://chat.example.com"},
		{"Env without proxy", "", "https://env.example.com/convos", nil, "https://env.example.com/convos"},
		{"Cloudflare tunnel", "1", "", map[string]string{"X-Forwarded-Proto": "https"}, "https://chat.example.com"},
		{"Forwarded host", "1", "", map[string]string{"X-Forwarded-Proto": "https", "X-Forwarded-Host": "proxy.example.com"}, "https://proxy.example.com"},
		{"Env beats forwarded headers", "1", "https://env.example.com/", map[string]string{"X-Forwarded-Host": "proxy.example.com"}, "https://env.example.com/"},
		{"X-Request-Base beats env", "1", "https://env.example.com/", map[string]string{"X-Request-Base": "https://proxy.example.com/convos"}, "https://proxy.example.com/convos"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			s := &Server{Config: &config.Config{ReverseProxy: tt.proxy, RequestBaseURL: tt.requestBase}}
			req := httptest.NewRequestWithContext(t.Context(), "GET", "http://chat.example.com/", nil)
			for k, v := range tt.headers {
				req.Header.Set(k, v)
			}
			if got := s.requestBaseURL(req).String(); got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}
