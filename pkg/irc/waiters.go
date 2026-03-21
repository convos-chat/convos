package irc

import "sync"

// waiterMap is a generic, goroutine-safe map for pending IRC reply correlations.
// It is used to associate an outgoing command (keyed by e.g. nick or channel)
// with a value (e.g. a conversation ID or request ID) that is needed when the
// server reply arrives. The zero value is ready for use.
type waiterMap[V any] struct {
	mu sync.Mutex
	m  map[string]V
}

// set stores val under key, initialising the map if necessary.
func (w *waiterMap[V]) set(key string, val V) {
	w.mu.Lock()
	if w.m == nil {
		w.m = make(map[string]V)
	}
	w.m[key] = val
	w.mu.Unlock()
}

// take atomically retrieves and removes the entry for key.
// Returns the zero value and false if key is not present.
func (w *waiterMap[V]) take(key string) (V, bool) {
	w.mu.Lock()
	val, ok := w.m[key]
	if ok {
		delete(w.m, key)
	}
	w.mu.Unlock()
	return val, ok
}
