package irc

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/convos-chat/convos/pkg/core"
)

var pushHTTPClient = &http.Client{Timeout: 15 * time.Second}

// persistNotification saves a highlighted message to the user's notification log
// and sends a Web Push notification if enabled.
func (c *Connection) persistNotification(convID, from, message string, msgType core.MessageType, ts int64) {
	msg := core.Notification{
		ConnectionID:   c.ID(),
		ConversationID: convID,
		From:           from,
		Message:        message,
		Type:           msgType,
		Timestamp:      ts,
	}
	err := c.User().Core().Backend().SaveNotification(c.User(), msg)
	if err != nil {
		slog.Error("Failed to save notification", "error", err)
	}

	c.sendWebPush(msg)
}

// sendWebPush sends a Web Push notification to all subscribed devices.
func (c *Connection) sendWebPush(notification core.Notification) {
	user := c.User()
	subs := user.Subscriptions()
	if len(subs) == 0 {
		return
	}

	pub, priv, err := user.Core().Settings().VAPIDKeys()
	if err != nil {
		slog.Error("Failed to get VAPID keys for push", "error", err)
		return
	}

	payload, err := json.Marshal(map[string]any{
		"title": fmt.Sprintf("%s in %s", notification.From, notification.ConversationID),
		"body":  notification.Message,
		"tag":   "convos-" + notification.ConversationID,
		"icon":  "/images/convos-icon-light.png",
		"data": map[string]string{
			"url": fmt.Sprintf("/chat/%s/%s", c.ID(), url.PathEscape(notification.ConversationID)),
		},
	})
	if err != nil {
		slog.Error("Failed to marshal push payload", "error", err)
		return
	}

	// RFC 8292 VAPID requires the "sub" JWT claim to be either an HTTPS URL or
	// a mailto: URI. Apple enforces HTTPS. Prefer the server's base URL when it
	// is HTTPS; fall back to the contact email (the webpush library prepends
	// "mailto:" automatically, so strip any existing prefix first).
	var subscriber string
	if base := user.Core().Settings().BaseURL(); base != nil && base.Scheme == "https" {
		subscriber = base.String()
	} else {
		subscriber = strings.TrimPrefix(user.Core().Settings().Contact(), "mailto:")
		if subscriber == "" {
			subscriber = "admin@example.com"
		}
	}

	for _, sub := range subs {
		go func(s webpush.Subscription) {
			slog.Debug("Sending push notification", "endpoint", s.Endpoint, "payload", string(payload))
			resp, err := webpush.SendNotification(payload, &s, &webpush.Options{
				Subscriber:      subscriber,
				RecordSize:      2048, // Android Firefox fails with larger payloads, so limit to 2KB
				VAPIDPublicKey:  pub,
				VAPIDPrivateKey: priv,
				TTL:             3600, // 1 hour
				Urgency:         "high",
				Topic:           "convos",
				HTTPClient:      pushHTTPClient,
			})
			if err != nil {
				slog.Error("Failed to send push notification", "error", err)
				return
			}
			defer resp.Body.Close()

			if resp.StatusCode >= 300 {
				body, _ := io.ReadAll(resp.Body)
				if resp.StatusCode == http.StatusGone || resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusForbidden {
					// Subscription is no longer valid, remove it
					slog.Warn("Push subscription invalid, removing", "status", resp.StatusCode, "body", string(body), "endpoint", s.Endpoint)
					user.RemoveSubscription(s.Endpoint)
					_ = user.Save()
				} else {
					slog.Warn("Push notification delivery failed", "status", resp.StatusCode, "body", string(body), "endpoint", s.Endpoint)
				}
			}
		}(sub)
	}
}
