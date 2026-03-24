package core

import (
	"sync"
	"testing"
)

func TestRGet(t *testing.T) {
	t.Parallel()
	var mu sync.RWMutex
	val := "hello"
	if got := rGet(&mu, &val); got != "hello" {
		t.Fatalf("rGet: got %q, want %q", got, "hello")
	}
}

func TestRGetInt(t *testing.T) {
	t.Parallel()
	var mu sync.RWMutex
	val := 42
	if got := rGet(&mu, &val); got != 42 {
		t.Fatalf("rGet: got %d, want %d", got, 42)
	}
}

func TestWSet(t *testing.T) {
	t.Parallel()
	var mu sync.RWMutex
	var val string
	wSet(&mu, &val, "world")
	if val != "world" {
		t.Fatalf("wSet: got %q, want %q", val, "world")
	}
}

func TestWSetInt(t *testing.T) {
	t.Parallel()
	var mu sync.RWMutex
	var val int
	wSet(&mu, &val, 99)
	if val != 99 {
		t.Fatalf("wSet: got %d, want %d", val, 99)
	}
}
