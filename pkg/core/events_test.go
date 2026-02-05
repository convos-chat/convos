package core

import (
	"sync"
	"testing"
	"time"
)

const (
	testUID      = "testUserID"
	testEventMsg = "message"
)

func TestNewEventEmitter(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	if e == nil {
		t.Fatal("NewEventEmitter() returned nil")
	}
	if e.SubscriberCount() != 0 {
		t.Errorf("SubscriberCount() = %d, want 0", e.SubscriberCount())
	}
}

func TestEventEmitterSubscribe(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()

	sub := e.Subscribe()
	if sub == nil {
		t.Fatal("Subscribe() returned nil")
	}

	if e.SubscriberCount() != 1 {
		t.Errorf("SubscriberCount() = %d, want 1", e.SubscriberCount())
	}

	sub.Close()

	// Allow time for cleanup
	time.Sleep(10 * time.Millisecond)

	if e.SubscriberCount() != 0 {
		t.Errorf("SubscriberCount() after Close() = %d, want 0", e.SubscriberCount())
	}
}

func TestEventEmitterEmitUser(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	sub := e.Subscribe()
	defer sub.Close()

	event := map[string]any{
		"event":         "message",
		"connection_id": "irc-libera",
		"from":          "alice",
		"message":       "Hello!",
	}

	e.EmitUser(testUID, event)

	select {
	case received := <-sub.Events():
		m, ok := received.(map[string]any)
		if !ok {
			t.Fatalf("Expected map[string]any, got %T", received)
		}
		if m["event"] != testEventMsg {
			t.Errorf("event = %q, want %q", m["event"], testEventMsg)
		}
		if m["from"] != "alice" {
			t.Errorf("from = %q, want %q", m["from"], "alice")
		}
		if m["ts"] == nil {
			t.Error("ts should be set automatically")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}
}

func TestEventEmitterSubscribeUser(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	sub := e.SubscribeUser(testUID)
	defer sub.Close()

	// Emit event for user2 (should be filtered out)
	e.EmitUser("user2", map[string]any{"event": testEventMsg})

	// Emit event for testUID (should be received)
	e.EmitUser(testUID, map[string]any{"event": testEventMsg})

	select {
	case received := <-sub.Events():
		m, ok := received.(map[string]any)
		if !ok {
			t.Fatalf("Expected map[string]any, got %T", received)
		}
		if m["event"] != testEventMsg {
			t.Errorf("event = %q, want %q", m["event"], testEventMsg)
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}

	// Verify no more events (user2's event should have been filtered)
	select {
	case ev := <-sub.Events():
		t.Errorf("Unexpected event: %+v", ev)
	case <-time.After(50 * time.Millisecond):
		// Expected
	}
}

func TestEventEmitterBroadcastSubscriber(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()

	// Subscribe with empty userID (broadcast subscriber, receives all events)
	sub := e.Subscribe()
	defer sub.Close()

	e.EmitUser("user1", map[string]any{"event": "state", "user": "user1"})
	e.EmitUser("user2", map[string]any{"event": "state", "user": "user2"})

	// Should receive both events
	for i, expected := range []string{"user1", "user2"} {
		select {
		case received := <-sub.Events():
			m, ok := received.(map[string]any)
			if !ok {
				t.Fatalf("Event %d: expected map, got %T", i, received)
			}
			if m["user"] != expected {
				t.Errorf("Event %d: user = %q, want %q", i, m["user"], expected)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatalf("Timeout waiting for event %d", i)
		}
	}
}

func TestEventEmitterMultipleSubscribers(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	sub1 := e.Subscribe()
	sub2 := e.Subscribe()
	defer sub1.Close()
	defer sub2.Close()

	if e.SubscriberCount() != 2 {
		t.Errorf("SubscriberCount() = %d, want 2", e.SubscriberCount())
	}

	e.EmitUser(testUID, map[string]any{"event": testEventMsg})

	// Both should receive
	for i, sub := range []*Subscription{sub1, sub2} {
		select {
		case received := <-sub.Events():
			m, ok := received.(map[string]any)
			if !ok {
				t.Fatalf("Subscriber %d: expected map, got %T", i, received)
			}
			if m["event"] != testEventMsg {
				t.Errorf("Subscriber %d: event = %q, want %q", i, m["event"], testEventMsg)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatalf("Subscriber %d: Timeout waiting for event", i)
		}
	}
}

func TestEventEmitterConcurrency(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	const numSubscribers = 10
	const numEvents = 100

	var wg sync.WaitGroup
	received := make([]int, numSubscribers)

	// Create subscribers
	subs := make([]*Subscription, numSubscribers)
	for i := range numSubscribers {
		subs[i] = e.Subscribe()
		idx := i
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range subs[idx].Events() {
				received[idx]++
			}
		}()
	}

	// Emit events concurrently
	for i := range numEvents {
		go func(_ int) {
			e.EmitUser(testUID, map[string]any{"event": testEventMsg})
		}(i)
	}

	// Wait a bit for events to propagate
	time.Sleep(100 * time.Millisecond)

	// Close all subscribers
	for _, sub := range subs {
		sub.Close()
	}

	wg.Wait()

	// Each subscriber should have received events
	for i, count := range received {
		if count == 0 {
			t.Errorf("Subscriber %d received 0 events", i)
		}
	}
}

func TestSubscriptionCloseTwice(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	sub := e.Subscribe()

	// Should not panic
	sub.Close()
	sub.Close()
}

func TestEventEmitterSetBufferSize(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	e.SetBufferSize(5)

	sub := e.Subscribe()
	defer sub.Close()

	// Fill up the buffer
	for i := range 5 {
		e.EmitUser(testUID, map[string]any{"event": testEventMsg, "i": i})
	}

	// This should be dropped (buffer full, non-blocking)
	e.EmitUser(testUID, map[string]any{"event": testEventMsg, "i": 5})

	count := 0
	for {
		select {
		case <-sub.Events():
			count++
		case <-time.After(50 * time.Millisecond):
			if count != 5 {
				t.Errorf("Received %d events, want 5", count)
			}
			return
		}
	}
}

func TestEventEmitterTimestamp(t *testing.T) {
	t.Parallel()

	e := NewEventEmitter()
	sub := e.Subscribe()
	defer sub.Close()

	// Event without ts should get one added
	e.EmitUser(testUID, map[string]any{"event": "state"})

	select {
	case received := <-sub.Events():
		m, ok := received.(map[string]any)
		if !ok {
			t.Fatalf("expected map[string]any, got %T", received)
		}
		ts, ok := m["ts"].(string)
		if !ok || ts == "" {
			t.Error("ts should be set automatically as string")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}

	// Event with ts should keep it
	e.EmitUser(testUID, map[string]any{"event": "state", "ts": "custom-ts"})

	select {
	case received := <-sub.Events():
		m, ok := received.(map[string]any)
		if !ok {
			t.Fatalf("expected map[string]any, got %T", received)
		}
		if m["ts"] != "custom-ts" {
			t.Errorf("ts = %q, want %q", m["ts"], "custom-ts")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}
}
