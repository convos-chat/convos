package core

import (
	"sync"
	"time"
)

// Subscription represents an event subscription.
type Subscription struct {
	id       uint64
	userID   string
	events   chan any
	emitter  *EventEmitter
	closed   bool
	closedMu sync.Mutex
}

// Events returns the channel for receiving events.
func (s *Subscription) Events() <-chan any {
	return s.events
}

// Close unsubscribes and closes the event channel.
func (s *Subscription) Close() {
	s.closedMu.Lock()
	if s.closed {
		s.closedMu.Unlock()
		return
	}
	s.closed = true
	s.closedMu.Unlock()

	s.emitter.unsubscribe(s.id)
	close(s.events)
}

// EventEmitter provides pub/sub functionality for events.
type EventEmitter struct {
	mu            sync.RWMutex
	subscriptions map[uint64]*Subscription
	nextID        uint64
	bufferSize    int
}

// NewEventEmitter creates a new event emitter.
func NewEventEmitter() *EventEmitter {
	return &EventEmitter{
		subscriptions: make(map[uint64]*Subscription),
		bufferSize:    100,
	}
}

// SetBufferSize sets the buffer size for new subscriptions.
func (e *EventEmitter) SetBufferSize(size int) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.bufferSize = size
}

// Subscribe creates a new subscription for all events.
func (e *EventEmitter) Subscribe() *Subscription {
	return e.SubscribeUser("")
}

// SubscribeUser creates a subscription for events for a specific user.
func (e *EventEmitter) SubscribeUser(userID string) *Subscription {
	e.mu.Lock()
	defer e.mu.Unlock()

	e.nextID++
	sub := &Subscription{
		id:      e.nextID,
		userID:  userID,
		events:  make(chan any, e.bufferSize),
		emitter: e,
	}
	e.subscriptions[sub.id] = sub
	return sub
}

// unsubscribe removes a subscription by ID.
func (e *EventEmitter) unsubscribe(id uint64) {
	e.mu.Lock()
	defer e.mu.Unlock()
	delete(e.subscriptions, id)
}

// EmitUser sends a flat event map to all subscribers for the given user.
// The event map is sent directly to the WebSocket as JSON.
func (e *EventEmitter) EmitUser(userID string, event map[string]any) {
	if _, ok := event["ts"]; !ok {
		event["ts"] = time.Now().UTC().Format(time.RFC3339)
	}

	e.mu.RLock()
	defer e.mu.RUnlock()

	for _, sub := range e.subscriptions {
		sub.closedMu.Lock()
		if sub.closed {
			sub.closedMu.Unlock()
			continue
		}

		if sub.userID == "" || sub.userID == userID {
			select {
			case sub.events <- event:
			default:
				// Buffer full, skip event (non-blocking)
			}
		}
		sub.closedMu.Unlock()
	}
}

// SubscriberCount returns the number of active subscribers.
func (e *EventEmitter) SubscriberCount() int {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return len(e.subscriptions)
}

