package handler

import (
	"context"
	"syscall"

	"github.com/convos-chat/convos/pkg/api"
)

// GetSettings implements api.StrictServerInterface.
func (h *Handler) GetSettings(ctx context.Context, request api.GetSettingsRequestObject) (api.GetSettingsResponseObject, error) {
	if h.GetUserFromCtx(ctx) == nil {
		return nil, ErrUnauthorized
	}
	return api.GetSettings200JSONResponse(h.settingsToAPI()), nil
}

// UpdateSettings implements api.StrictServerInterface.
func (h *Handler) UpdateSettings(ctx context.Context, request api.UpdateSettingsRequestObject) (api.UpdateSettingsResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	if !user.HasRole("admin") {
		return nil, ErrForbidden
	}

	s := h.Core.Settings()
	b := request.Body

	if b.Contact != nil {
		s.SetContact(*b.Contact)
	}
	if b.DefaultConnection != nil {
		s.SetDefaultConnection(*b.DefaultConnection)
	}
	if b.ForcedConnection != nil {
		s.SetForcedConnection(*b.ForcedConnection)
	}
	if b.OpenToPublic != nil {
		s.SetOpenToPublic(*b.OpenToPublic)
	}
	if b.OrganizationName != nil {
		s.SetOrganizationName(*b.OrganizationName)
	}
	if b.OrganizationUrl != nil {
		s.SetOrganizationURL(*b.OrganizationUrl)
	}
	if b.VideoService != nil {
		s.SetVideoService(*b.VideoService)
	}

	if err := s.Save(); err != nil {
		return nil, err
	}

	// Auto-create connection profile when default_connection is set
	if b.DefaultConnection != nil && *b.DefaultConnection != "" {
		h.ensureConnectionProfile(*b.DefaultConnection, true)
	}

	return api.UpdateSettings200JSONResponse(h.settingsToAPI()), nil
}

func (h *Handler) settingsToAPI() api.ServerSettings {
	s := h.Core.Settings()

	contact := s.Contact()
	defaultConn := s.DefaultConnection()
	forced := s.ForcedConnection()
	open := s.OpenToPublic()
	orgName := s.OrganizationName()
	orgURL := s.OrganizationURL()
	video := s.VideoService()

	baseURL := s.BaseURL().String()

	res := api.ServerSettings{
		BaseUrl:           &baseURL,
		Contact:           &contact,
		DefaultConnection: &defaultConn,
		ForcedConnection:  &forced,
		OpenToPublic:      &open,
		OrganizationName:  &orgName,
		OrganizationUrl:   &orgURL,
		VideoService:      &video,
	}

	if usage := h.getDiskUsage(h.Core.Home()); usage != nil {
		res.DiskUsage = usage
	}

	return res
}

func (h *Handler) getDiskUsage(path string) *struct {
	BlockSize   *int64  `json:"block_size,omitempty"`
	BlocksFree  *uint64 `json:"blocks_free,omitempty"`
	BlocksTotal *uint64 `json:"blocks_total,omitempty"`
	BlocksUsed  *uint64 `json:"blocks_used,omitempty"`
	InodesFree  *uint64 `json:"inodes_free,omitempty"`
	InodesTotal *uint64 `json:"inodes_total,omitempty"`
	InodesUsed  *uint64 `json:"inodes_used,omitempty"`
} {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(path, &stat); err != nil {
		return nil
	}
	blockSize := stat.Bsize
	blocksFree := stat.Bavail

	blocksTotal := stat.Blocks
	blocksUsed := blocksTotal - blocksFree
	inodesFree := stat.Ffree
	inodesTotal := stat.Files
	inodesUsed := inodesTotal - inodesFree

	return &struct {
		BlockSize   *int64  `json:"block_size,omitempty"`
		BlocksFree  *uint64 `json:"blocks_free,omitempty"`
		BlocksTotal *uint64 `json:"blocks_total,omitempty"`
		BlocksUsed  *uint64 `json:"blocks_used,omitempty"`
		InodesFree  *uint64 `json:"inodes_free,omitempty"`
		InodesTotal *uint64 `json:"inodes_total,omitempty"`
		InodesUsed  *uint64 `json:"inodes_used,omitempty"`
	}{
		BlockSize:   &blockSize,
		BlocksFree:  &blocksFree,
		BlocksTotal: &blocksTotal,
		BlocksUsed:  &blocksUsed,
		InodesFree:  &inodesFree,
		InodesTotal: &inodesTotal,
		InodesUsed:  &inodesUsed,
	}
}
