package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestConnectionLifecycle(t *testing.T) {
	t.Parallel()
	s, c := setupServer()
	email := "conn-test@example.com"
	password := "pass"
	cookie := loginUser(t, s, c, email, password)

	// 1. List Connections - Should be empty
	req := httptest.NewRequest("GET", "/api/connections", nil)
	req.AddCookie(cookie)
	w := httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("List connections failed: %d %s", w.Code, w.Body.String())
	}

	var listResp map[string]any
	if err := json.NewDecoder(w.Body).Decode(&listResp); err != nil {
		t.Fatalf("Failed to decode list response: %v", err)
	}
	conns, ok := listResp["connections"].([]any)
	if !ok {
		t.Fatalf("Expected []any for connections, got %T", listResp["connections"])
	}
	if len(conns) != 0 {
		t.Errorf("Expected 0 connections, got %d", len(conns))
	}

	// 2. Create Connection
	body := map[string]string{"url": "irc://irc.libera.chat"}
	jsonBody, _ := json.Marshal(body)
	req = httptest.NewRequest("POST", "/api/connections", bytes.NewReader(jsonBody))
	req.AddCookie(cookie)
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Create connection failed: %d %s", w.Code, w.Body.String())
	}

	var connResp map[string]any
	if err := json.NewDecoder(w.Body).Decode(&connResp); err != nil {
		t.Fatalf("Failed to decode create response: %v", err)
	}

	connID, ok := connResp["connection_id"].(string)
	if !ok || connID == "" {
		t.Errorf("No connection_id in response: %v", connResp)
	}
	if connResp["url"] != "irc://irc.libera.chat?nick=conn_test" {
		t.Errorf("Expected url irc://irc.libera.chat?nick=conn_test, got %v", connResp["url"])
	}

	// 3. List Connections - Should have 1
	req = httptest.NewRequest("GET", "/api/connections", nil)
	req.AddCookie(cookie)
	w = httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if err := json.NewDecoder(w.Body).Decode(&listResp); err != nil {
		t.Fatalf("Failed to decode: %v", err)
	}
	conns, ok = listResp["connections"].([]any)
	if !ok {
		t.Fatalf("Expected []any for connections, got %T", listResp["connections"])
	}
	if len(conns) != 1 {
		t.Errorf("Expected 1 connection, got %d", len(conns))
	}

	// 4. Remove Connection
	req = httptest.NewRequest("DELETE", "/api/connection/"+connID, nil)
	req.AddCookie(cookie)
	w = httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Remove connection failed: %d %s", w.Code, w.Body.String())
	}

	// 5. List Connections - Should be empty again
	req = httptest.NewRequest("GET", "/api/connections", nil)
	req.AddCookie(cookie)
	w = httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if err := json.NewDecoder(w.Body).Decode(&listResp); err != nil {
		t.Fatalf("Failed to decode: %v", err)
	}
	conns, ok = listResp["connections"].([]any)
	if !ok {
		t.Fatalf("Expected []any for connections, got %T", listResp["connections"])
	}
	if len(conns) != 0 {
		t.Errorf("Expected 0 connections after delete, got %d", len(conns))
	}
}

func TestCreateConnectionInvalid(t *testing.T) {
	t.Parallel()
	s, c := setupServer()
	cookie := loginUser(t, s, c, "invalid@example.com", "pass")

	// Empty URL
	body := map[string]string{"url": ""}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest("POST", "/api/connections", bytes.NewReader(jsonBody))
	req.AddCookie(cookie)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	s.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request for empty URL, got %d", w.Code)
	}
}
