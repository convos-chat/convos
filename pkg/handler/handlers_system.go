package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/version"
)

// CheckForUpdates implements api.StrictServerInterface.
// Fetches the latest version from convos.chat and compares with the running version.
func (h *Handler) CheckForUpdates(ctx context.Context, request api.CheckForUpdatesRequestObject) (api.CheckForUpdatesResponseObject, error) {
	running := parseVersion(version.Version)

	available, err := fetchLatestVersion(ctx, version.Version)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch latest version: %w", err)
	}

	// Never report a downgrade
	if available < running {
		available = running
	}

	return api.CheckForUpdates200JSONResponse{
		Available: &available,
		Running:   &running,
	}, nil
}

// fetchLatestVersion queries convos.chat/api for the latest released version.
func fetchLatestVersion(ctx context.Context, runningVersion string) (float32, error) {
	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://convos.chat/api", nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("X-Convos-Version", runningVersion)

	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("convos.chat returned %d: %w", resp.StatusCode, err)
	}

	var body struct {
		Info struct {
			Version json.Number `json:"version"`
		} `json:"info"`
	}
	if err = json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return 0, err
	}

	v, err := body.Info.Version.Float64()
	if err != nil {
		return 0, err
	}
	return float32(v), nil
}

// parseVersion extracts a float32 from a version string.
// Handles "8.07", "0.99", "dev", etc.
func parseVersion(s string) float32 {
	v, err := strconv.ParseFloat(s, 32)
	if err != nil {
		return 0
	}
	return float32(v)
}
