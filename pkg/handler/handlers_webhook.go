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

	var message string
	switch provider {
	case "github":
		var event string
		if r != nil {
			event = r.Header.Get("X-GitHub-Event")
		}
		message = formatGitHubMessage(event, payload)
	default:
		message = fmt.Sprintf("[%s] webhook received", provider)
	}

	if message == "" {
		return api.Webhook200JSONResponse{"status": "ignored"}, nil
	}

	// Forward the message to the first admin user's first connected connection
	status := h.forwardWebhookMessage(message)
	return api.Webhook200JSONResponse{"status": status}, nil
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

// forwardWebhookMessage sends a message to the first admin user's first connected IRC channel.
func (h *Handler) forwardWebhookMessage(message string) []map[string]string {
	var status []map[string]string

	for _, user := range h.Core.Users() {
		if !user.HasRole("admin") {
			continue
		}
		for _, conn := range user.Connections() {
			if string(conn.State()) != "connected" {
				continue
			}
			convos := conn.Conversations()
			if len(convos) == 0 {
				continue
			}
			// Send to the first channel conversation
			for _, conv := range convos {
				if !strings.HasPrefix(conv.ID(), "#") {
					continue
				}
				err := conn.Send(conv.ID(), message)
				entry := map[string]string{
					"connection_id":   conn.ID(),
					"conversation_id": conv.ID(),
					"error":           "",
				}
				if err != nil {
					entry["error"] = err.Error()
				}
				status = append(status, entry)
				return status // send to first matching channel only
			}
		}
	}

	if len(status) == 0 {
		status = append(status, map[string]string{"error": "No connected admin channel found."})
	}
	return status
}

// formatGitHubMessage formats a GitHub webhook event into an IRC message.
func formatGitHubMessage(event string, payload map[string]any) string {
	repo := jsonString(payload, "repository", "full_name")
	sender := jsonString(payload, "sender", "login")

	switch event {
	case "push":
		ref := getStr(payload, "ref")
		branch := strings.TrimPrefix(ref, "refs/heads/")
		commits, _ := payload["commits"].([]any)
		if len(commits) == 0 {
			return ""
		}
		msg := fmt.Sprintf("[%s] %s pushed %d commit(s) to %s", repo, sender, len(commits), branch)
		// Include first commit message
		if first, ok := commits[0].(map[string]any); ok {
			if cm := getStr(first, "message"); cm != "" {
				cm = strings.SplitN(cm, "\n", 2)[0] // first line only
				msg += fmt.Sprintf(": %s", cm)
			}
		}
		return msg

	case "pull_request":
		action := getStr(payload, "action")
		pr, _ := payload["pull_request"].(map[string]any)
		if pr == nil {
			return ""
		}
		if sender == "dependabot[bot]" || sender == "renovate[bot]" {
			return ""
		}
		title := getStr(pr, "title")
		url := getStr(pr, "html_url")
		return fmt.Sprintf("[%s] %s %s pull request #%s: %s — %s",
			repo, sender, action, getStr(pr, "number"), title, url)

	case "issue_comment":
		action := getStr(payload, "action")
		if action != "created" {
			return ""
		}
		issue, _ := payload["issue"].(map[string]any)
		comment, _ := payload["comment"].(map[string]any)
		if issue == nil || comment == nil {
			return ""
		}
		url := getStr(comment, "html_url")
		return fmt.Sprintf("[%s] %s commented on issue #%s: %s",
			repo, sender, getStr(issue, "number"), url)

	case "issues":
		action := getStr(payload, "action")
		issue, _ := payload["issue"].(map[string]any)
		if issue == nil {
			return ""
		}
		title := getStr(issue, "title")
		url := getStr(issue, "html_url")
		return fmt.Sprintf("[%s] %s %s issue #%s: %s — %s",
			repo, sender, action, getStr(issue, "number"), title, url)

	case "create":
		refType := getStr(payload, "ref_type")
		ref := getStr(payload, "ref")
		return fmt.Sprintf("[%s] %s created %s %s", repo, sender, refType, ref)

	case "delete":
		refType := getStr(payload, "ref_type")
		ref := getStr(payload, "ref")
		return fmt.Sprintf("[%s] %s deleted %s %s", repo, sender, refType, ref)

	case "ping":
		zen := getStr(payload, "zen")
		return fmt.Sprintf("[%s] GitHub ping: %s", repo, zen)

	default:
		if event != "" {
			return fmt.Sprintf("[%s] %s triggered %s event", repo, sender, event)
		}
		return ""
	}
}

// jsonString extracts a nested string from a JSON map: jsonString(m, "a", "b") → m["a"]["b"].
func jsonString(m map[string]any, keys ...string) string {
	current := m
	for i, key := range keys {
		if i == len(keys)-1 {
			return getStr(current, key)
		}
		next, ok := current[key].(map[string]any)
		if !ok {
			return ""
		}
		current = next
	}
	return ""
}

// getStr extracts a string value from a map, handling number-to-string conversion.
func getStr(m map[string]any, key string) string {
	v := m[key]
	switch val := v.(type) {
	case string:
		return val
	case float64:
		return fmt.Sprintf("%.0f", val)
	default:
		if v != nil {
			return fmt.Sprintf("%v", v)
		}
		return ""
	}
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
