//go:build windows

package handler

import "golang.org/x/sys/windows"

// getDiskUsage reports disk usage for the volume containing path.
// Windows file systems have no inode concept, so the inode counters
// are always returned as zero.
func getDiskUsage(path string) (int64, uint64, uint64, uint64, uint64, error) {
	pathPtr, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return 0, 0, 0, 0, 0, err
	}

	var freeBytesAvailable uint64
	var totalBytes uint64
	var totalFreeBytes uint64
	if err := windows.GetDiskFreeSpaceEx(pathPtr, &freeBytesAvailable, &totalBytes, &totalFreeBytes); err != nil {
		return 0, 0, 0, 0, 0, err
	}

	const blockSize = 4096
	return blockSize, freeBytesAvailable / blockSize, totalBytes / blockSize, 0, 0, nil
}