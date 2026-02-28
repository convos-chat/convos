package handler

import (
	"context"
	"log/slog"
	"net/url"

	"github.com/convos-chat/convos/pkg/api"
)

type diskUsage = struct {
	BlockSize   *int64  `json:"block_size,omitempty"`
	BlocksFree  *uint64 `json:"blocks_free,omitempty"`
	BlocksTotal *uint64 `json:"blocks_total,omitempty"`
	BlocksUsed  *uint64 `json:"blocks_used,omitempty"`
	InodesFree  *uint64 `json:"inodes_free,omitempty"`
	InodesTotal *uint64 `json:"inodes_total,omitempty"`
	InodesUsed  *uint64 `json:"inodes_used,omitempty"`
}

// GetSettings implements api.StrictServerInterface.
func (h *Handler) GetSettings(ctx context.Context, request api.GetSettingsRequestObject) (api.GetSettingsResponseObject, error) {
	if _, err := h.requireUser(ctx); err != nil {
		return nil, err
	}
	return api.GetSettings200JSONResponse(h.settingsToAPI()), nil
}

// UpdateSettings implements api.StrictServerInterface.
func (h *Handler) UpdateSettings(ctx context.Context, request api.UpdateSettingsRequestObject) (api.UpdateSettingsResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
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
		return api.UpdateSettings500JSONResponse{
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse(err.Error())),
		}, nil
	}

	// Auto-create connection profile when default_connection is set
	if b.DefaultConnection != nil && *b.DefaultConnection != "" {
		h.createDefaultProfile(*b.DefaultConnection)
	}

	return api.UpdateSettings200JSONResponse(h.settingsToAPI()), nil
}

func (h *Handler) createDefaultProfile(rawURL string) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return
	}
	profile := h.Core.ConnectionProfile(u)
	if profile == nil {
		return
	}

	profile.SetIsDefault(true)
	profile.SetSkipQueue(false)
	if err := profile.Save(); err != nil {
		slog.Error("Failed to save default connection profile", "error", err)
	}
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

	// Determine OIDC login URL based on authenticator type
	oidcURL := ""
	if h.Authenticator.Name() == "oidc" {
		oidcURL = "/auth/oidc/login"
	}

	baseURL := s.BaseURL().String()

	res := api.ServerSettings{
		BaseUrl:           &baseURL,
		Contact:           &contact,
		DefaultConnection: &defaultConn,
		ForcedConnection:  &forced,
		OpenToPublic:      &open,
		OrganizationName:  &orgName,
		OrganizationUrl:   &orgURL,
		OidcLoginUrl:      &oidcURL,
		VideoService:      &video,
	}

	if usage := h.getDiskUsage(h.Core.Home()); usage != nil {
		res.DiskUsage = usage
	}

	return res
}

func (h *Handler) getDiskUsage(path string) *diskUsage {
	blockSize, blocksFree, blocksTotal, inodesFree, inodesTotal, err := getDiskUsage(path)
	if err != nil {
		return nil
	}
	blocksUsed := blocksTotal - blocksFree
	inodesUsed := inodesTotal - inodesFree

	return &diskUsage{
		BlockSize:   &blockSize,
		BlocksFree:  &blocksFree,
		BlocksTotal: &blocksTotal,
		BlocksUsed:  &blocksUsed,
		InodesFree:  &inodesFree,
		InodesTotal: &inodesTotal,
		InodesUsed:  &inodesUsed,
	}
}
