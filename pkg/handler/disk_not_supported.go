//go:build wasm || windows

// FIXME: we can probably support windows through another syscall

package handler

import "errors"

func getDiskUsage(path string) (int64, uint64, uint64, uint64, uint64, error) {
	return 0, 0, 0, 0, 0, errors.New("disk usage not supported on this platform")
}
