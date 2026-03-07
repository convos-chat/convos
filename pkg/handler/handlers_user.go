package handler

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
)

// LoginUser implements api.StrictServerInterface.
func (h *Handler) LoginUser(ctx context.Context, request api.LoginUserRequestObject) (api.LoginUserResponseObject, error) {
	r, err := h.getRequest(ctx)
	if err != nil {
		return nil, err
	}
	w, err := h.getResponseWriter(ctx)
	if err != nil {
		return nil, err
	}

	// Use authenticator instead of direct password validation
	authReq := core.AuthRequest{
		Email:    string(request.Body.Email),
		Password: request.Body.Password,
		Context:  ctx,
	}

	result, err := h.Authenticator.Authenticate(authReq)
	if err != nil {
		return api.LoginUser400JSONResponse{
			BadRequestJSONResponse: api.BadRequestJSONResponse(api.ErrResponse(err.Error())),
		}, nil
	}

	user := result.User

	// Handle auto-registration (used by header and LDAP auth)
	if result.AutoCreate {
		user, err = h.createAutoRegisteredUser(authReq.Email, authReq.Password, result.Roles)
		if err != nil {
			return api.LoginUser500JSONResponse{
				InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(
					api.ErrResponse(err.Error())),
			}, nil
		}
	}

	if err = h.saveUserSession(r, w, user); err != nil {
		return nil, err
	}

	return api.LoginUser200JSONResponse(api.ToUser(user, true, true)), nil
}

// LogoutUser implements api.StrictServerInterface.
func (h *Handler) LogoutUser(ctx context.Context, request api.LogoutUserRequestObject) (api.LogoutUserResponseObject, error) {
	r, err := h.getRequest(ctx)
	if err != nil {
		return nil, err
	}
	w, err := h.getResponseWriter(ctx)
	if err != nil {
		return nil, err
	}

	session, err := h.Store.Get(r, "convos")
	if err != nil {
		slog.Warn("Failed to get session: " + err.Error())
	}
	session.Values["email"] = nil
	session.Options.MaxAge = -1
	if err = session.Save(r, w); err != nil {
		return nil, err
	}

	return api.LogoutUser302Response{}, nil
}

// RegisterUser implements api.StrictServerInterface.
func (h *Handler) RegisterUser(ctx context.Context, request api.RegisterUserRequestObject) (api.RegisterUserResponseObject, error) {
	r, err := h.getRequest(ctx)
	if err != nil {
		return nil, err
	}
	w, err := h.getResponseWriter(ctx)
	if err != nil {
		return nil, err
	}

	email := string(request.Body.Email)
	if email == "" || len(request.Body.Password) < 10 {
		return api.RegisterUser400JSONResponse{
			BadRequestJSONResponse: api.BadRequestJSONResponse(api.ErrResponse("Email and password (min length 10) are required")),
		}, nil
	}

	hasToken := request.Body.Token != nil && *request.Body.Token != ""
	existingUser := h.Core.GetUser(email)
	users := h.Core.Users()

	// First user can always register (admin setup).
	// Subsequent users need either open_to_public or a valid invite token.
	if len(users) > 0 {
		if resp, done := h.validateRegistration(hasToken, existingUser, email, request.Body); done {
			return resp, nil
		}

		// Valid invite for existing user — update their password
		if hasToken && existingUser != nil {
			return h.updateExistingUserViaInvite(existingUser, request.Body.Password, r, w)
		}
	}

	// Register new user
	user, err := h.Core.User(email)
	if err != nil {
		return api.RegisterUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to create user: " + err.Error())),
		}, nil
	}

	if err = user.SetPassword(request.Body.Password); err != nil {
		return api.RegisterUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to set password: " + err.Error())),
		}, nil
	}

	// Auto-give admin role to first user
	if len(users) == 0 {
		user.GiveRole("admin")
	}

	if err = user.Save(); err != nil {
		return api.RegisterUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to save user: " + err.Error())),
		}, nil
	}

	// Auto-create connection from default_connection setting
	if defaultConn := h.Core.Settings.DefaultConnection(); defaultConn != "" {
		conn := irc.NewConnection(defaultConn, user)
		user.AddConnection(conn)

		// Auto-create conversation from URL path
		if ch := channelFromURL(defaultConn); ch != "" {
			conv := core.NewConversation(ch, conn)
			conn.AddConversation(conv)
		}
		if err = h.Core.Backend.SaveConnection(conn); err != nil {
			slog.Error("Failed to save conversation", "err", err)
		}

		// Auto-connect
		go func() {
			if err = conn.Connect(); err != nil {
				slog.Error("Failed to auto-connect", "err", err)
			}
		}()
	}

	if err = h.saveUserSession(r, w, user); err != nil {
		return nil, err
	}

	return api.RegisterUser200JSONResponse(api.ToUser(user, true, true)), nil
}

// validateRegistration checks whether a non-first-user registration is allowed.
// Returns (response, true) if registration should be rejected, or (nil, false) to continue.
func (h *Handler) validateRegistration(hasToken bool, existingUser *core.User, email string, body *api.RegisterUserJSONRequestBody) (api.RegisterUserResponseObject, bool) {
	if !hasToken && !h.Core.Settings.OpenToPublic() {
		return api.RegisterUser401JSONResponse{
			UnauthorizedJSONResponse: api.UnauthorizedJSONResponse(api.ErrResponse("Convos registration is not open to public.")),
		}, true
	}

	if !hasToken && existingUser != nil {
		return api.RegisterUser401JSONResponse{
			UnauthorizedJSONResponse: api.UnauthorizedJSONResponse(api.ErrResponse("Email is taken.")),
		}, true
	}

	if hasToken {
		if err := h.validateInviteRequest(email, existingUser, body); err != nil {
			return api.RegisterUser401JSONResponse{
				UnauthorizedJSONResponse: api.UnauthorizedJSONResponse(api.ErrResponse(err.Error())),
			}, true
		}
	}

	return nil, false
}

// updateExistingUserViaInvite handles invite-based password update for an existing user.
func (h *Handler) updateExistingUserViaInvite(user *core.User, password string, r *http.Request, w http.ResponseWriter) (api.RegisterUserResponseObject, error) {
	if err := user.SetPassword(password); err != nil {
		return api.RegisterUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to set password.")),
		}, nil
	}
	if err := user.Save(); err != nil {
		return api.RegisterUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to save user.")),
		}, nil
	}

	if err := h.saveUserSession(r, w, user); err != nil {
		return nil, err
	}
	return api.RegisterUser200JSONResponse(api.ToUser(user, true, true)), nil
}

// validateInviteRequest checks the invite token and expiration from a registration request.
func (h *Handler) validateInviteRequest(email string, existingUser *core.User, body *api.RegisterUserJSONRequestBody) error {
	token := ""
	if body.Token != nil {
		token = *body.Token
	}
	if token == "" {
		return ErrInvalidInviteToken
	}

	// Parse and validate expiration
	var exp int64
	if body.Exp != nil {
		parsed, err := strconv.ParseInt(*body.Exp, 10, 64)
		if err != nil || parsed < time.Now().Unix() {
			return ErrInvalidInviteToken
		}
		exp = parsed
	}

	// Determine password for HMAC: existing user's hash or local_secret
	password := h.Core.Settings.LocalSecret()
	if existingUser != nil {
		password = existingUser.Password()
	}

	if !h.validateInviteToken(email, token, exp, password) {
		return ErrInvalidInviteToken
	}

	return nil
}

// GetUser implements api.StrictServerInterface.
func (h *Handler) GetUser(ctx context.Context, request api.GetUserRequestObject) (api.GetUserResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}

	params := request.Params
	includeConns := params.Connections == nil || *params.Connections
	includeConvs := params.Conversations == nil || *params.Conversations

	return api.GetUser200JSONResponse(api.ToUser(user, includeConns, includeConvs)), nil
}

// InviteUser implements api.StrictServerInterface.
func (h *Handler) InviteUser(ctx context.Context, request api.InviteUserRequestObject) (api.InviteUserResponseObject, error) {
	if err := h.requireAdmin(ctx); err != nil {
		return nil, err
	}

	email := string(request.Email)
	exp := time.Now().Add(h.InviteExpiry).Unix()

	// Use target user's password hash, or local_secret for new users
	target := h.Core.GetUser(email)
	password := h.Core.Settings.LocalSecret()
	if target != nil {
		password = target.Password()
	}

	token := h.generateInviteToken(email, exp, password)
	existing := target != nil
	expires := time.Unix(exp, 0).UTC()

	inviteURL := h.makeAbsoluteURL("/register")
	inviteURL += "?email=" + url.QueryEscape(email) +
		"&exp=" + strconv.FormatInt(exp, 10) +
		"&token=" + token

	return api.InviteUser200JSONResponse{
		Existing: &existing,
		Expires:  &expires,
		Url:      inviteURL,
	}, nil
}

// GetUsers implements api.StrictServerInterface.
func (h *Handler) GetUsers(ctx context.Context, request api.GetUsersRequestObject) (api.GetUsersResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	if !user.HasRole("admin") {
		return api.GetUsers200JSONResponse{Users: &[]api.User{}}, nil
	}

	coreUsers := h.Core.Users()
	users := make([]api.User, len(coreUsers))
	for i, u := range coreUsers {
		users[i] = api.ToUserSummary(u)
	}

	return api.GetUsers200JSONResponse{Users: &users}, nil
}

// UpdateUser implements api.StrictServerInterface.
func (h *Handler) UpdateUser(ctx context.Context, request api.UpdateUserRequestObject) (api.UpdateUserResponseObject, error) {
	caller, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}

	targetEmail := string(request.Email)
	target := h.Core.GetUser(targetEmail)
	if target == nil {
		return api.UpdateUser404JSONResponse{
			NotFoundJSONResponse: api.NotFoundJSONResponse(api.ErrResponse("User not found")),
		}, nil
	}

	// Non-admins can only update themselves
	if caller.Email() != target.Email() && !caller.HasRole("admin") {
		return nil, ErrForbidden
	}

	b := request.Body
	if b.Password != nil && *b.Password != "" {
		if err := target.SetPassword(*b.Password); err != nil {
			return api.UpdateUser500JSONResponse{ //nolint:nilerr // HTTP error response
				InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to set password: " + err.Error())),
			}, nil
		}
	}
	if b.HighlightKeywords != nil {
		target.SetHighlightKeywords(*b.HighlightKeywords)
	}
	if b.Roles != nil && caller.HasRole("admin") {
		// Clear existing roles and set new ones
		for _, role := range target.Roles() {
			target.TakeRole(role)
		}
		for _, role := range *b.Roles {
			target.GiveRole(role)
		}
	}

	if err := target.Save(); err != nil {
		return api.UpdateUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to save user: " + err.Error())),
		}, nil
	}

	return api.UpdateUser200JSONResponse(api.ToUser(target, true, true)), nil
}

// DeleteUser implements api.StrictServerInterface.
func (h *Handler) DeleteUser(ctx context.Context, request api.DeleteUserRequestObject) (api.DeleteUserResponseObject, error) {
	if err := h.requireAdmin(ctx); err != nil {
		return nil, err
	}

	targetEmail := string(request.Email)
	if err := h.Core.RemoveUser(targetEmail); err != nil {
		return api.DeleteUser500JSONResponse{ //nolint:nilerr // HTTP error response
			InternalServerErrorJSONResponse: api.InternalServerErrorJSONResponse(api.ErrResponse("Failed to delete user: " + err.Error())),
		}, nil
	}

	msg := "User deleted"
	return api.DeleteUser200JSONResponse{Message: &msg}, nil
}

// Helpers

// createAutoRegisteredUser creates and configures a new user for auto-registration scenarios.
func (h *Handler) createAutoRegisteredUser(email, password string, roles []string) (*core.User, error) {
	user, err := h.Core.User(email)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Set password if provided (LDAP users get auto-registered with password)
	if password != "" {
		if err = user.SetPassword(password); err != nil {
			return nil, fmt.Errorf("failed to set password: %w", err)
		}
	}

	// Assign roles
	for _, role := range roles {
		user.GiveRole(role)
	}

	if err = user.Save(); err != nil {
		return nil, fmt.Errorf("failed to save user: %w", err)
	}

	return user, nil
}
