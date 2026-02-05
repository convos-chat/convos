package embed

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestProviderName(t *testing.T) {
	t.Parallel()
	tests := []struct {
		input    string
		expected string
	}{
		{"github.com", "Github"},
		{"www.google.com", "Google"},
		{"example.co.uk", "Example"},
		{"127.0.0.1", "127.0.0.1"},
		{"localhost", "Localhost"},
	}

	for _, tt := range tests {
		got := providerName(tt.input)
		if got != tt.expected {
			t.Errorf("providerName(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

func TestFetch_Photo(t *testing.T) {
	t.Parallel()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write([]byte("fake-image-data"))
	}))
	defer ts.Close()

	client := NewClient()
	link, err := client.Fetch(context.Background(), ts.URL+"/test.png", "")
	if err != nil {
		t.Fatalf("Fetch failed: %v", err)
	}

	if link.Type != "photo" {
		t.Errorf("Expected type photo, got %q", link.Type)
	}
	if link.Title != "test.png" {
		t.Errorf("Expected title test.png, got %q", link.Title)
	}
	if !strings.Contains(link.HTML, "<img src=") {
		t.Errorf("Expected image tag in HTML, got %q", link.HTML)
	}
}

func TestFetch_Rich(t *testing.T) {
	t.Parallel()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(`
			<html>
				<head>
					<title>Page Title</title>
					<meta property="og:description" content="OG Description">
					<meta name="author" content="Author Name">
				</head>
				<body>Content</body>
			</html>
		`))
	}))
	defer ts.Close()

	client := NewClient()
	link, err := client.Fetch(context.Background(), ts.URL, "")
	if err != nil {
		t.Fatalf("Fetch failed: %v", err)
	}

	if link.Type != "rich" {
		t.Errorf("Expected type rich, got %q", link.Type)
	}
	if link.Title != "Page Title" {
		t.Errorf("Expected title Page Title, got %q", link.Title)
	}
	if link.Description != "OG Description" {
		t.Errorf("Expected description OG Description, got %q", link.Description)
	}
	if link.AuthorName != "Author Name" {
		t.Errorf("Expected author Author Name, got %q", link.AuthorName)
	}
	if !strings.Contains(link.HTML, "<h3>Page Title</h3>") {
		t.Errorf("Expected h3 title in HTML, got %q", link.HTML)
	}
}

func TestFetch_Caching(t *testing.T) {
	t.Parallel()
	callCount := 0
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte("ok"))
	}))
	defer ts.Close()

	client := NewClient()
	_, _ = client.Fetch(context.Background(), ts.URL, "")
	_, _ = client.Fetch(context.Background(), ts.URL, "")

	if callCount != 1 {
		t.Errorf("Expected 1 HTTP call due to caching, got %d", callCount)
	}
}

func TestFetch_Error(t *testing.T) {
	t.Parallel()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer ts.Close()

	client := NewClient()
	_, err := client.Fetch(context.Background(), ts.URL, "")
	if err == nil {
		t.Fatal("Expected error for 404 status, got nil")
	}
	if !strings.Contains(err.Error(), "404") {
		t.Errorf("Expected error to contain 404, got %q", err.Error())
	}
}
