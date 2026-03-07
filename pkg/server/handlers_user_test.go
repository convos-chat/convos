package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

const sessionCookieName = "convos"

func TestRegisterUser(t *testing.T) {
	t.Parallel()

	s, _ := setupServer()

	body := map[string]string{
		"email":    "test@example.com",
		"password": "password123",
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/register", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 OK, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]any
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if resp["email"] != "test@example.com" {
		t.Errorf("Expected email test@example.com, got %v", resp["email"])
	}
}

func TestLoginUser(t *testing.T) {
	t.Parallel()

	s, c := setupServer()

	// Pre-create user via Core.User() so it's in the user map
	u, _ := c.User("test@example.com")
	if err := u.SetPassword("password123"); err != nil {
		t.Fatalf("SetPassword failed: %v", err)
	}
	if err := u.Save(); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	body := map[string]string{
		"email":    "test@example.com",
		"password": "password123",
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequestWithContext(t.Context(), "POST", "/api/user/login", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 OK, got %d: %s", w.Code, w.Body.String())
	}

	// Check cookie
	cookies := w.Result().Cookies()
	found := false
	for _, c := range cookies {
		if c.Name == sessionCookieName {
			found = true
			break
		}
	}
	if !found {
		t.Error("Expected session cookie not found")
	}
}
