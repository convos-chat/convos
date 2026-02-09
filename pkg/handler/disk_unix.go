//go:build !wasm && !windows

package handler

import "golang.org/x/sys/unix"

func getDiskUsage(path string) (int64, uint64, uint64, uint64, uint64, error) {
	var stat unix.Statfs_t
	if err := unix.Statfs(path, &stat); err != nil {
		return 0, 0, 0, 0, 0, err
	}
	return stat.Bsize, stat.Bavail, stat.Blocks, stat.Ffree, stat.Files, nil
}
