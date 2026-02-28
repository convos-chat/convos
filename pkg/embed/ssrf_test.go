package embed

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestIsPrivateIP(t *testing.T) {
	t.Parallel()
	cases := []struct {
		ip      string
		private bool
	}{
		// Private / reserved — must be blocked
		{"127.0.0.1", true},
		{"127.0.0.2", true},
		{"10.0.0.1", true},
		{"10.255.255.255", true},
		{"172.16.0.1", true},
		{"172.31.255.255", true},
		{"192.168.1.1", true},
		{"169.254.169.254", true}, // AWS/GCP metadata
		{"100.64.0.1", true},     // CGNAT / Tailscale
		{"0.0.0.1", true},
		{"::1", true},
		{"fe80::1", true},
		{"fc00::1", true},

		// Public — must be allowed
		{"1.1.1.1", false},
		{"8.8.8.8", false},
		{"93.184.216.34", false}, // example.com
		{"2606:4700:4700::1111", false},
	}

	for _, tc := range cases {
		ip := net.ParseIP(tc.ip)
		if ip == nil {
			t.Fatalf("bad test IP: %q", tc.ip)
		}
		got := isPrivateIP(ip)
		if got != tc.private {
			t.Errorf("isPrivateIP(%q) = %v, want %v", tc.ip, got, tc.private)
		}
	}
}

func TestSafeDialContextBlocksPrivate(t *testing.T) {
	t.Parallel()
	privateHosts := []string{
		"127.0.0.1:80",
		"10.0.0.1:80",
		"192.168.1.1:80",
		"169.254.169.254:80",
		"172.16.0.1:80",
		"[::1]:80",
	}
	for _, addr := range privateHosts {
		_, err := safeDialContext(context.Background(), "tcp", addr)
		if err == nil {
			t.Errorf("safeDialContext(%q) should have been blocked", addr)
		}
	}
}

func TestFetchBlocksPrivateSchemes(t *testing.T) {
	t.Parallel()
	client := NewClient()
	blocked := []string{
		"file:///etc/passwd",
		"ftp://example.com/",
		"gopher://example.com/",
	}
	for _, u := range blocked {
		_, err := client.Fetch(context.Background(), u, "")
		if err == nil {
			t.Errorf("Fetch(%q) should have been blocked", u)
		}
	}
}

func TestFetchBlocksPrivateIPs(t *testing.T) {
	t.Parallel()
	client := NewClient()
	blocked := []string{
		"http://127.0.0.1/",
		"http://169.254.169.254/latest/meta-data/",
		"http://10.0.0.1/",
		"http://192.168.1.1/",
	}
	for _, u := range blocked {
		_, err := client.Fetch(context.Background(), u, "")
		if err == nil {
			t.Errorf("Fetch(%q) should have been blocked", u)
		}
	}
}

func TestFetchBlocksRedirectToPrivate(t *testing.T) {
	t.Parallel()

	// A public server that redirects to a private IP.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://169.254.169.254/", http.StatusFound)
	}))
	defer srv.Close()

	client := NewClient()
	// Swap the safe client for one that points at our local test server but
	// still enforces the redirect check.
	client.HTTPClient = &http.Client{
		Transport: &http.Transport{DialContext: safeDialContext},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if ip := net.ParseIP(req.URL.Hostname()); ip != nil && isPrivateIP(ip) {
				return net.InvalidAddrError("refusing redirect to private IP: " + ip.String())
			}
			return nil
		},
	}

	_, err := client.Fetch(context.Background(), srv.URL+"/redirect", "")
	if err == nil || !strings.Contains(err.Error(), "private") {
		t.Errorf("expected private-IP redirect to be blocked, got err=%v", err)
	}
}
