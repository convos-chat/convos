package server

import (
	"io/fs"
	"slices"
)

// overlayFS layers an upper filesystem over a lower one. Files in the upper
// layer take precedence. ReadDir merges entries from both layers.
type overlayFS struct {
	upper fs.FS
	lower fs.FS
}

func (o *overlayFS) Open(name string) (fs.File, error) {
	if f, err := o.upper.Open(name); err == nil {
		return f, nil
	}
	return o.lower.Open(name)
}

func (o *overlayFS) ReadFile(name string) ([]byte, error) {
	if data, err := fs.ReadFile(o.upper, name); err == nil {
		return data, nil
	}
	return fs.ReadFile(o.lower, name)
}

func (o *overlayFS) Stat(name string) (fs.FileInfo, error) {
	if info, err := fs.Stat(o.upper, name); err == nil {
		return info, nil
	}
	return fs.Stat(o.lower, name)
}

func (o *overlayFS) ReadDir(name string) ([]fs.DirEntry, error) {
	upperEntries, upperErr := fs.ReadDir(o.upper, name)
	lowerEntries, lowerErr := fs.ReadDir(o.lower, name)

	if upperErr != nil && lowerErr != nil {
		return nil, lowerErr
	}

	seen := make(map[string]bool, len(upperEntries))
	merged := make([]fs.DirEntry, 0, len(upperEntries)+len(lowerEntries))
	for _, e := range upperEntries {
		seen[e.Name()] = true
		merged = append(merged, e)
	}
	for _, e := range lowerEntries {
		if !seen[e.Name()] {
			merged = append(merged, e)
		}
	}

	slices.SortFunc(merged, func(a, b fs.DirEntry) int {
		if a.Name() < b.Name() {
			return -1
		}
		if a.Name() > b.Name() {
			return 1
		}
		return 0
	})

	return merged, nil
}
