package handler

import (
	"context"
	"net/url"
	"regexp"
	"strings"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
)

// ListConnectionProfiles implements api.StrictServerInterface.
func (h *Handler) ListConnectionProfiles(ctx context.Context, request api.ListConnectionProfilesRequestObject) (api.ListConnectionProfilesResponseObject, error) {
	profiles, err := h.Core.Backend().LoadConnectionProfiles()
	if err != nil {
		return nil, err
	}

	// If no profiles exist, return a default one
	if len(profiles) == 0 {
		defaultURL := h.Core.Settings().DefaultConnection()
		if defaultURL == "" {
			defaultURL = "irc://irc.libera.chat:6697"
		}
		profiles = append(profiles, core.ConnectionProfileData{
			ID:                 profileID(defaultURL),
			URL:                defaultURL,
			MaxBulkMessageSize: 3,
			MaxMessageLength:   512,
			ServiceAccounts:    []string{"chanserv", "nickserv"},
		})
	}

	settings := h.Core.Settings()
	defaultConn := settings.DefaultConnection()
	forced := settings.ForcedConnection()

	res := make([]api.ConnectionProfile, len(profiles))
	for i, p := range profiles {
		// Compute is_default/is_forced from settings, matching Perl behavior
		p.IsDefault = defaultConn != "" && sameHost(p.URL, defaultConn)
		p.IsForced = p.IsDefault && forced
		res[i] = toAPIConnectionProfile(p)
	}

	// If none matched as default, mark the first one
	if defaultConn == "" && len(res) > 0 {
		t := true
		res[0].IsDefault = &t
	}
	if err := h.Core.Settings().Save(); err != nil {
		return nil, err
	}

	return api.ListConnectionProfiles200JSONResponse{Profiles: &res}, nil
}

// SaveConnectionProfile implements api.StrictServerInterface.
func (h *Handler) SaveConnectionProfile(ctx context.Context, request api.SaveConnectionProfileRequestObject) (api.SaveConnectionProfileResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	if !user.HasRole("admin") {
		return nil, ErrForbidden
	}

	p := fromAPIConnectionProfile(request.Body)
	if err := h.Core.Backend().SaveConnectionProfile(p); err != nil {
		return nil, err
	}

	// When marked as default, update and persist settings
	if p.IsDefault {
		h.Core.Settings().SetDefaultConnection(p.URL)
		h.Core.Settings().SetForcedConnection(p.IsForced)
		if err := h.Core.Settings().Save(); err != nil {
			return nil, err
		}
	}

	return api.SaveConnectionProfile200JSONResponse(toAPIConnectionProfile(p)), nil
}

// RemoveConnectionProfile implements api.StrictServerInterface.
func (h *Handler) RemoveConnectionProfile(ctx context.Context, request api.RemoveConnectionProfileRequestObject) (api.RemoveConnectionProfileResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	if !user.HasRole("admin") {
		return nil, ErrForbidden
	}

	if err := h.Core.Backend().DeleteConnectionProfile(request.Id); err != nil {
		return nil, err
	}

	return api.RemoveConnectionProfile200JSONResponse{}, nil
}

func toAPIConnectionProfile(p core.ConnectionProfileData) api.ConnectionProfile {
	return api.ConnectionProfile{
		Id:                 &p.ID,
		IsDefault:          &p.IsDefault,
		IsForced:           &p.IsForced,
		MaxBulkMessageSize: &p.MaxBulkMessageSize,
		MaxMessageLength:   &p.MaxMessageLength,
		ServiceAccounts:    &p.ServiceAccounts,
		SkipQueue:          &p.SkipQueue,
		Url:                p.URL,
		WebircPassword:     &p.WebircPassword,
	}
}

func fromAPIConnectionProfile(p *api.ConnectionProfile) core.ConnectionProfileData {
	res := core.ConnectionProfileData{
		URL:                p.Url,
		MaxBulkMessageSize: 3,
		MaxMessageLength:   512,
		ServiceAccounts:    []string{"chanserv", "nickserv"},
	}
	if p.IsDefault != nil {
		res.IsDefault = *p.IsDefault
	}
	if p.IsForced != nil {
		res.IsForced = *p.IsForced
	}
	if p.MaxBulkMessageSize != nil {
		res.MaxBulkMessageSize = *p.MaxBulkMessageSize
	}
	if p.MaxMessageLength != nil {
		res.MaxMessageLength = *p.MaxMessageLength
	}
	if p.ServiceAccounts != nil {
		res.ServiceAccounts = *p.ServiceAccounts
	}
	if p.WebircPassword != nil {
		res.WebircPassword = *p.WebircPassword
	}

	res.ID = profileID(p.Url)
	return res
}

var nonWordRe = regexp.MustCompile(`[\W_]+`)

// profileID derives a profile ID from a URL, matching Perl's pretty_connection_name.
// Example: "irc://irc.libera.chat:6697/%23convos" → "irc-libera"
func profileID(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return rawURL
	}

	name := u.Hostname()
	if name == "" {
		return u.Scheme
	}
	if name == "127.0.0.1" {
		name = "localhost"
	}

	// Strip common prefixes
	name = strings.TrimPrefix(name, "irc.")
	name = strings.TrimPrefix(name, "chat.")

	// Strip TLD (.com, .net, .no, etc. — 2-3 char)
	if idx := strings.LastIndex(name, "."); idx >= 0 {
		tld := name[idx+1:]
		if len(tld) >= 2 && len(tld) <= 3 {
			name = name[:idx]
		}
	}
	// Strip .chat specifically (4 chars)
	name = strings.TrimSuffix(name, ".chat")

	name = nonWordRe.ReplaceAllString(name, "-")
	name = strings.Trim(name, "-")

	return u.Scheme + "-" + name
}

// sameHost compares two URLs by hostname (ignoring port, path, etc.)
func sameHost(a, b string) bool {
	ua, err1 := url.Parse(a)
	ub, err2 := url.Parse(b)
	if err1 != nil || err2 != nil {
		return a == b
	}
	return ua.Hostname() == ub.Hostname()
}
