package irc

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/convos-chat/convos/pkg/core"
)

// persistNotification saves a highlighted message to the user's notification log
// and sends a Web Push notification if enabled.
func (c *Connection) persistNotification(convID, from, message, msgType string, ts int64) {
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

	// We can't customize email yet, so use a dummy one if contact is not set.
	// In real world, this should be admin's email.
	subscriber := user.Core().Settings().Contact()
	if subscriber == "" {
		subscriber = "mailto:admin@example.com"
	} else if !strings.HasPrefix(subscriber, "mailto:") && !strings.HasPrefix(subscriber, "http") {
		subscriber = "mailto:" + subscriber
	}

	for _, sub := range subs {
		go func(s webpush.Subscription) {
			slog.Debug("Sending push notification", "endpoint", s.Endpoint, "payload", string(payload))
			resp, err := webpush.SendNotification(payload, &s, &webpush.Options{
				Subscriber:      subscriber,
				VAPIDPublicKey:  pub,
				VAPIDPrivateKey: priv,
				TTL:             3600, // 1 hour
				Urgency:         "high",
				Topic:           "convos",
			})
			if err != nil {
				slog.Error("Failed to send push notification", "error", err)
				return
			}
			defer resp.Body.Close()

			if resp.StatusCode == http.StatusGone || resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusForbidden {
				// Subscription is no longer valid, remove it
				user.RemoveSubscription(s.Endpoint)
				_ = user.Save()
			} else if resp.StatusCode >= 300 {
				slog.Warn("Push notification delivery failed", "status", resp.StatusCode, "endpoint", s.Endpoint)
			}
		}(sub)
	}
}
