package core

import "sync"

// rGet reads a value under a read lock.
func rGet[T any](mu *sync.RWMutex, ptr *T) T {
	mu.RLock()
	defer mu.RUnlock()
	return *ptr
}

// wSet writes a value under a write lock.
func wSet[T any](mu *sync.RWMutex, ptr *T, val T) {
	mu.Lock()
	defer mu.Unlock()
	*ptr = val
}
