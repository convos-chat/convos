package handler

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"strings"

	"github.com/convos-chat/convos/pkg/api"
)

// Webhook implements api.StrictServerInterface.
// Validates the source IP and forwards webhook payloads as IRC messages.
func (h *Handler) Webhook(ctx context.Context, request api.WebhookRequestObject) (api.WebhookResponseObject, error) {
	r, _ := h.getRequest(ctx)

	// Validate source IP against allowed networks
	if r != nil && len(h.WebhookNets) > 0 {
		remoteIP := extractIP(r.RemoteAddr)
		if !h.isAllowedWebhookIP(remoteIP) {
			slog.Warn("Webhook rejected: IP not in allowed networks", "ip", remoteIP)
			return api.Webhook200JSONResponse{"errors": []map[string]string{{"message": fmt.Sprintf("Invalid source IP %s.", remoteIP)}}}, nil
		}
	}

	if request.Body == nil {
		return api.Webhook200JSONResponse{"errors": []map[string]string{{"message": "Empty payload."}}}, nil
	}

	provider := request.ProviderName
	payload := *request.Body

	if h.Bot != nil {
		if h.Bot.HandleWebhook(provider, payload) {
			return api.Webhook200JSONResponse{"status": "sent"}, nil
		}
	}

	return api.Webhook200JSONResponse{"status": "ignored"}, nil
}

// isAllowedWebhookIP checks whether the given IP is in the allowed webhook networks.
func (h *Handler) isAllowedWebhookIP(ipStr string) bool {
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false
	}
	for _, cidr := range h.WebhookNets {
		if cidr.Contains(ip) {
			return true
		}
	}
	return false
}

// extractIP returns just the IP portion of a host:port address.
func extractIP(remoteAddr string) string {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return remoteAddr
	}
	return host
}

// ParseWebhookNetworks parses a comma-separated list of CIDR ranges.
func ParseWebhookNetworks(s string) []*net.IPNet {
	nets := make([]*net.IPNet, 0)
	for cidr := range strings.SplitSeq(s, ",") {
		cidr = strings.TrimSpace(cidr)
		if cidr == "" {
			continue
		}
		_, ipNet, err := net.ParseCIDR(cidr)
		if err != nil {
			slog.Warn("Invalid webhook network CIDR", "cidr", cidr, "error", err)
			continue
		}
		nets = append(nets, ipNet)
	}
	return nets
}
