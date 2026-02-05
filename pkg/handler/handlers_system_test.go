package handler

import (
	"testing"
)

func TestParseVersion(t *testing.T) {
	t.Parallel()
	tests := []struct {
		input    string
		expected float32
	}{
		{"8.07", 8.07},
		{"0.99", 0.99},
		{"dev", 0},
		{"v1.2", 0}, // strconv.ParseFloat doesn't like 'v'
	}

	for _, tt := range tests {
		got := parseVersion(tt.input)
		if got != tt.expected {
			t.Errorf("parseVersion(%q) = %v, want %v", tt.input, got, tt.expected)
		}
	}
}
