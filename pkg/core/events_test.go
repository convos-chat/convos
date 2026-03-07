package core_test

import (
	"sync"
	"testing"
	"time"

	"github.com/convos-chat/convos/pkg/core"
)

const testUID = "testUserID"

func TestNewEventEmitter(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()
	if e == nil {
		t.Fatal("NewEventEmitter( returned nil")
	}
	if e.SubscriberCount() != 0 {
		t.Errorf("SubscriberCount() = %d, want 0", e.SubscriberCount())
	}
}

func TestEventEmitterSubscribe(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()

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

	e := core.NewEventEmitter()
	sub := e.Subscribe()
	defer sub.Close()

	e.EmitUser(testUID, &core.MessageEvent{
		BaseEvent: core.BaseEvent{ConnectionID: "irc-libera"},
		From:      "alice",
		Message:   "Hello!",
		Type:      core.MessageTypePrivate,
	})

	select {
	case received := <-sub.Events:
		ev, ok := received.(*core.MessageEvent)
		if !ok {
			t.Fatalf("Expected *core.MessageEvent, got %T", received)
		}
		if ev.From != "alice" {
			t.Errorf("From = %v, want alice", ev.From)
		}
		if ev.TS == "" {
			t.Error("TS should be set automatically")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}
}

func TestEventEmitterSubscribeUser(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()
	sub := e.SubscribeUser(testUID)
	defer sub.Close()

	// Emit event for user2 (should be filtered out)
	e.EmitUser("user2", &core.MessageEvent{
		BaseEvent: core.BaseEvent{ConnectionID: "conn"},
		From:      "user",
		Message:   "msg",
		Type:      core.MessageTypePrivate,
	})

	// Emit event for testUID (should be received)
	e.EmitUser(testUID, &core.MessageEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, From: "user", Message: "msg", Type: core.MessageTypePrivate})

	select {
	case received := <-sub.Events:
		_, ok := received.(*core.MessageEvent)
		if !ok {
			t.Fatalf("Expected *core.MessageEvent, got %T", received)
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}

	// Verify no more events (user2's event should have been filtered)
	select {
	case ev := <-sub.Events:
		t.Errorf("Unexpected event: %+v", ev)
	case <-time.After(50 * time.Millisecond):
		// Expected
	}
}

func TestEventEmitterBroadcastSubscriber(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()

	// Subscribe with empty userID (broadcast subscriber, receives all events)
	sub := e.Subscribe()
	defer sub.Close()

	e.EmitUser("user1", &core.StateConnectionEvent{BaseEvent: core.BaseEvent{ConnectionID: "user1"}, State: core.StateConnected, Message: "Connected"})
	e.EmitUser("user2", &core.StateConnectionEvent{BaseEvent: core.BaseEvent{ConnectionID: "user2"}, State: core.StateConnected, Message: "Connected"})

	// Should receive both events
	for i, expected := range []string{"user1", "user2"} {
		select {
		case received := <-sub.Events:
			ev, ok := received.(*core.StateConnectionEvent)
			if !ok {
				t.Fatalf("Event %d: expected *core.StateConnectionEvent, got %T", i, received)
			}
			if ev.ConnectionID != expected {
				t.Errorf("Event %d: ConnectionID = %q, want %q", i, ev.ConnectionID, expected)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatalf("Timeout waiting for event %d", i)
		}
	}
}

func TestEventEmitterMultipleSubscribers(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()
	sub1 := e.Subscribe()
	sub2 := e.Subscribe()
	defer sub1.Close()
	defer sub2.Close()

	if e.SubscriberCount() != 2 {
		t.Errorf("SubscriberCount() = %d, want 2", e.SubscriberCount())
	}

	e.EmitUser(testUID, &core.MessageEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, From: "user", Message: "msg", Type: core.MessageTypePrivate})

	// Both should receive
	for i, sub := range []*core.Subscription{sub1, sub2} {
		select {
		case received := <-sub.Events:
			_, ok := received.(*core.MessageEvent)
			if !ok {
				t.Fatalf("Subscriber %d: expected *core.MessageEvent, got %T", i, received)
			}
		case <-time.After(100 * time.Millisecond):
			t.Fatalf("Subscriber %d: Timeout waiting for event", i)
		}
	}
}

func TestEventEmitterConcurrency(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()
	const numSubscribers = 10
	const numEvents = 100

	var wg sync.WaitGroup
	received := make([]int, numSubscribers)

	// Create subscribers
	subs := make([]*core.Subscription, numSubscribers)
	for i := range numSubscribers {
		subs[i] = e.Subscribe()
		idx := i
		wg.Go(func() {
			for range subs[idx].Events {
				received[idx]++
			}
		})
	}

	// Emit events concurrently
	for i := range numEvents {
		go func(_ int) {
			e.EmitUser(testUID, &core.MessageEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, From: "user", Message: "msg", Type: core.MessageTypePrivate})
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

	e := core.NewEventEmitter()
	sub := e.Subscribe()

	// Should not panic
	sub.Close()
	sub.Close()
}

func TestEventEmitterSetBufferSize(t *testing.T) {
	t.Parallel()

	e := core.NewEventEmitter()
	e.SetBufferSize(5)

	sub := e.Subscribe()
	defer sub.Close()

	// Fill up the buffer
	for range 5 {
		e.EmitUser(testUID, &core.MessageEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, From: "user", Message: "msg", Type: core.MessageTypePrivate})
	}

	// This should be dropped (buffer full, non-blocking)
	e.EmitUser(testUID, &core.MessageEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, From: "user", Message: "dropped", Type: core.MessageTypePrivate})

	count := 0
	for {
		select {
		case <-sub.Events:
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

	e := core.NewEventEmitter()
	sub := e.Subscribe()
	defer sub.Close()

	// Event should have timestamp set by constructor
	e.EmitUser(testUID, &core.StateConnectionEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, State: core.StateConnected, Message: "Connected"})

	select {
	case received := <-sub.Events:
		ev, ok := received.(*core.StateConnectionEvent)
		if !ok {
			t.Fatalf("expected *core.StateConnectionEvent, got %T", received)
		}
		if ev.TS == "" {
			t.Error("TS should be set automatically")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}

	// Event can have custom timestamp
	customEvent := &core.StateConnectionEvent{BaseEvent: core.BaseEvent{ConnectionID: "conn"}, State: core.StateConnected, Message: "Connected"}
	customEvent.TS = "custom-ts"
	e.EmitUser(testUID, customEvent)

	select {
	case received := <-sub.Events:
		ev, ok := received.(*core.StateConnectionEvent)
		if !ok {
			t.Fatalf("expected *core.StateConnectionEvent, got %T", received)
		}
		if ev.TS != "custom-ts" {
			t.Errorf("TS = %q, want %q", ev.TS, "custom-ts")
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Timeout waiting for event")
	}
}
