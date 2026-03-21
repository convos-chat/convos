package irc

import (
	"sync"
	"testing"
)

func TestWaiterMap_SetAndTake(t *testing.T) {
	t.Parallel()
	var w waiterMap[string]

	w.set("key", "value")
	got, ok := w.take("key")
	if !ok {
		t.Fatal("expected ok=true after set")
	}
	if got != "value" {
		t.Errorf("got %q, want %q", got, "value")
	}
}

func TestWaiterMap_TakeMissing(t *testing.T) {
	t.Parallel()
	var w waiterMap[string]

	got, ok := w.take("missing")
	if ok {
		t.Error("expected ok=false for missing key")
	}
	if got != "" {
		t.Errorf("expected zero value, got %q", got)
	}
}

func TestWaiterMap_TakeDeletesEntry(t *testing.T) {
	t.Parallel()
	var w waiterMap[int]

	w.set("k", 42)
	w.take("k")
	_, ok := w.take("k")
	if ok {
		t.Error("second take should return ok=false after entry was consumed")
	}
}

func TestWaiterMap_ZeroValueUsable(t *testing.T) {
	t.Parallel()
	// No initialisation — zero value must work without panicking.
	var w waiterMap[any]
	w.set("x", 99)
	val, ok := w.take("x")
	if !ok || val != 99 {
		t.Errorf("zero-value waiterMap not usable: got %v, %v", val, ok)
	}
}

func TestWaiterMap_ConcurrentAccess(t *testing.T) {
	t.Parallel()
	var w waiterMap[int]
	const n = 100

	var wg sync.WaitGroup
	for i := range n {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			key := string(rune('a' + i%26))
			w.set(key, i)
			w.take(key)
		}(i)
	}
	wg.Wait()
}
