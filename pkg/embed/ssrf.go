package embed

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"time"
)

var (
	ErrPrivateIP        = errors.New("embed: connection to private IP refused")
	ErrNoAddresses      = errors.New("embed: no DNS addresses resolved")
	ErrTooManyRedirects = errors.New("embed: too many redirects")
	ErrUnsupportedScheme = errors.New("embed: unsupported scheme")
)

// privateRanges lists IP networks that must never be contacted by the embed
// client. Checked at dial time (after DNS resolution) to prevent SSRF via
// DNS rebinding.
var privateRanges = func() []*net.IPNet {
	cidrs := []string{
		"0.0.0.0/8",      // "This" network
		"10.0.0.0/8",     // RFC 1918 private
		"100.64.0.0/10",  // Shared address space (CGNAT / Tailscale)
		"127.0.0.0/8",    // Loopback
		"169.254.0.0/16", // Link-local (AWS/GCP metadata endpoints)
		"172.16.0.0/12",  // RFC 1918 private
		"192.168.0.0/16", // RFC 1918 private
		"198.51.100.0/24", // TEST-NET-2 (RFC 5737)
		"203.0.113.0/24",  // TEST-NET-3 (RFC 5737)
		"240.0.0.0/4",    // Reserved
		"::1/128",        // IPv6 loopback
		"fc00::/7",       // IPv6 unique-local
		"fe80::/10",      // IPv6 link-local
	}
	ranges := make([]*net.IPNet, 0, len(cidrs))
	for _, cidr := range cidrs {
		_, network, err := net.ParseCIDR(cidr)
		if err != nil {
			panic("embed: invalid private CIDR: " + cidr)
		}
		ranges = append(ranges, network)
	}
	return ranges
}()

// isPrivateIP reports whether ip falls within any private/reserved range.
func isPrivateIP(ip net.IP) bool {
	for _, network := range privateRanges {
		if network.Contains(ip) {
			return true
		}
	}
	return false
}

// safeDialContext is a net.Dialer.DialContext replacement that resolves the
// target hostname and refuses to connect if any resolved address is private.
// This must run at dial time (not at URL-parse time) to be safe against DNS
// rebinding: the check and the connection use the same resolved IP.
func safeDialContext(ctx context.Context, network, addr string) (net.Conn, error) {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return nil, fmt.Errorf("embed: bad address %q: %w", addr, err)
	}

	addrs, err := net.DefaultResolver.LookupIPAddr(ctx, host)
	if err != nil {
		return nil, fmt.Errorf("embed: DNS lookup %q: %w", host, err)
	}
	if len(addrs) == 0 {
		return nil, fmt.Errorf("%w: no addresses for %q", ErrNoAddresses, host)
	}

	// Refuse if any resolved address is private — an attacker could exploit
	// round-robin DNS to get a private IP on a subsequent connection even if
	// the first resolved address was public.
	for _, a := range addrs {
		if isPrivateIP(a.IP) {
			return nil, fmt.Errorf("%w: %s (%s)", ErrPrivateIP, a.IP, host)
		}
	}

	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return dialer.DialContext(ctx, network, net.JoinHostPort(addrs[0].IP.String(), port))
}

// newSafeHTTPClient returns an http.Client whose transport uses safeDialContext
// to block SSRF requests to private IP ranges.
func newSafeHTTPClient(timeout time.Duration) *http.Client {
	transport := &http.Transport{
		DialContext:         safeDialContext,
		DisableKeepAlives:   true, // avoid reusing connections that bypassed checks
		MaxIdleConns:        0,
		TLSHandshakeTimeout: 5 * time.Second,
	}
	return &http.Client{
		Timeout:   timeout,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return fmt.Errorf("%w", ErrTooManyRedirects)
			}
			// Explicit IP redirects (no DNS) also need a check.
			if ip := net.ParseIP(req.URL.Hostname()); ip != nil && isPrivateIP(ip) {
				return fmt.Errorf("%w: %s", ErrPrivateIP, ip)
			}
			return nil
		},
	}
}
