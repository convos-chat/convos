package handler

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/irc"
	"github.com/gorilla/sessions"
	openapi_types "github.com/oapi-codegen/runtime/types"
)

func TestRegisterUser_PasswordLength(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	// Test 9 character password (should fail if minLength: 10 is enforced)
	request := api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    openapi_types.Email("test@example.com"),
			Password: "123456789",
		},
	}

	resp, err := h.RegisterUser(ctx, request)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.RegisterUser400JSONResponse); !ok {
		t.Errorf("Expected api.RegisterUser400JSONResponse, got %T", resp)
	}
}

func TestGetUser_QueryParameters(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	// Mock connection
	rawURL := "irc://irc.libera.chat"
	conn := irc.NewConnection(rawURL, u)
	u.AddConnection(conn)

	// 1. connections=false, conversations=false
	req := httptest.NewRequest("GET", "/api/user?connections=false&conversations=false", nil)
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyUser, u)

	resp, err := h.GetUser(ctx, api.GetUserRequestObject{
		Params: api.GetUserParams{
			Connections:   ptr(false),
			Conversations: ptr(false),
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if r, ok := resp.(api.GetUser200JSONResponse); ok {
		if r.Connections != nil && len(*r.Connections) > 0 {
			t.Error("Expected no connections when connections=false")
		}
		if r.Conversations != nil && len(*r.Conversations) > 0 {
			t.Error("Expected no conversations when conversations=false")
		}
	} else {
		t.Fatalf("Unexpected response type: %T", resp)
	}
}

func TestGetUser_Fields(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	c.Settings().SetDefaultConnection("irc://irc.libera.chat")
	c.Settings().SetForcedConnection(true)
	c.Settings().SetVideoService("https://meet.jit.si/")

	u, _ := c.User("test@example.com")
	_ = u.Save()

	req := httptest.NewRequest("GET", "/api/user", nil)
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyUser, u)

	resp, err := h.GetUser(ctx, api.GetUserRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if r, ok := resp.(api.GetUser200JSONResponse); ok {
		if r.DefaultConnection == nil || *r.DefaultConnection == "" {
			t.Error("default_connection field is missing or empty")
		}
		if r.ForcedConnection == nil {
			t.Error("forced_connection field is missing")
		}
		if r.VideoService == nil || *r.VideoService == "" {
			t.Error("video_service field is missing or empty")
		}
	} else {
		t.Fatalf("Unexpected response type: %T", resp)
	}
}

func TestGetSettings_AuthAndDiskUsage(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	// Authenticated should return disk_usage
	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	resp, err := h.GetSettings(ctx, api.GetSettingsRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if r, ok := resp.(api.GetSettings200JSONResponse); ok {
		if r.DiskUsage == nil {
			t.Error("disk_usage field is missing in settings response")
		}
	} else {
		t.Fatalf("Unexpected response type: %T", resp)
	}
}

// Category 2 tests: fields that Perl runtime returns but neither spec originally defined.

func TestGetUser_RolesAndRemoteAddress(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	u.GiveRole("admin")
	_ = u.Save()
	u.SetRemoteAddress("127.0.0.1")

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.GetUser(ctx, api.GetUserRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.GetUser200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.Roles == nil {
		t.Fatal("roles field is missing")
	}
	if len(*r.Roles) != 1 || (*r.Roles)[0] != "admin" {
		t.Errorf("roles: got %v, want [admin]", *r.Roles)
	}

	if r.RemoteAddress == nil || *r.RemoteAddress != "127.0.0.1" {
		t.Errorf("remote_address: got %v, want '127.0.0.1'", r.RemoteAddress)
	}
}

func TestGetUser_ConversationFields(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	conn := irc.NewConnection("irc://irc.libera.chat", u)
	u.AddConnection(conn)

	conv := core.NewConversation("#test", conn)
	conn.AddConversation(conv)
	conv.SetFrozen("Not connected.")
	conv.SetNotifications(3)

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.GetUser(ctx, api.GetUserRequestObject{
		Params: api.GetUserParams{
			Connections:   ptr(true),
			Conversations: ptr(true),
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.GetUser200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.Conversations == nil || len(*r.Conversations) == 0 {
		t.Fatal("Expected at least one conversation")
	}

	found := false
	for _, conv := range *r.Conversations {
		if conv.ConversationId == "#test" {
			found = true
			if conv.Frozen == nil || *conv.Frozen != "Not connected." {
				t.Errorf("frozen field: got %v, want 'Not connected.'", conv.Frozen)
			}
			if conv.Notifications == nil || *conv.Notifications != 3 {
				t.Errorf("notifications field: got %v, want 3", conv.Notifications)
			}
			// info should be present (possibly empty map)
			if conv.Info == nil {
				t.Error("info field is missing")
			}
		}
	}
	if !found {
		t.Error("Conversation #test not found in response")
	}
}

func TestListConnectionProfiles_IdAndSkipQueue(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	profileID := testServer
	profile := core.ConnectionProfileData{
		ID:                 profileID,
		URL:                "irc://irc.libera.chat",
		IsDefault:          true,
		MaxBulkMessageSize: 3,
		MaxMessageLength:   512,
		ServiceAccounts:    []string{"chanserv", "nickserv"},
	}
	_ = backend.SaveConnectionProfile(profile)

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.ListConnectionProfiles(ctx, api.ListConnectionProfilesRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.ListConnectionProfiles200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.Profiles == nil || len(*r.Profiles) == 0 {
		t.Fatal("Expected at least one profile")
	}

	p := (*r.Profiles)[0]
	if p.Id == nil || *p.Id != profileID {
		t.Errorf("id field: got %v, want %q", p.Id, profileID)
	}
	if p.SkipQueue == nil {
		t.Error("skip_queue field is missing")
	}
}

func TestConversationMessages_EndField(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	conn := irc.NewConnection("irc://irc.libera.chat", u)
	u.AddConnection(conn)
	conv := core.NewConversation("#test", conn)
	conn.AddConversation(conv)

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.ConversationMessages(ctx, api.ConversationMessagesRequestObject{
		ConnectionId:   conn.ID(),
		ConversationId: conv.ID(),
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.ConversationMessages200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	// Empty conversation should return end=true
	if r.End == nil {
		t.Error("end field is missing from conversation messages response")
	} else if !*r.End {
		t.Error("end field should be true for empty conversation")
	}
}

func TestNotificationMessages_EndField(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.NotificationMessages(ctx, api.NotificationMessagesRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.NotificationMessages200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	// Empty notifications should return end=true
	if r.End == nil {
		t.Error("end field is missing from notification messages response")
	} else if !*r.End {
		t.Error("end field should be true for empty notifications")
	}
}

func TestSearchMessages_EndField(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	match := "anything"
	resp, err := h.SearchMessages(ctx, api.SearchMessagesRequestObject{
		Params: api.SearchMessagesParams{Match: &match},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.SearchMessages200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	// Empty search should return end=true
	if r.End == nil {
		t.Error("end field is missing from search messages response")
	} else if !*r.End {
		t.Error("end field should be true for empty search results")
	}
}

func TestGetSettings_BaseURL(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	baseURL, _ := url.Parse("http://localhost:3000")
	c.Settings().SetBaseURL(baseURL)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.GetSettings(ctx, api.GetSettingsRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.GetSettings200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.BaseUrl == nil || *r.BaseUrl == "" {
		t.Error("base_url field is missing or empty in settings response")
	}
	if r.BaseUrl != nil && *r.BaseUrl != "http://localhost:3000" {
		t.Errorf("base_url: got %q, want %q", *r.BaseUrl, "http://localhost:3000")
	}
}

// Category 3 tests: behavioral / implementation gaps.

func TestTimestampFormat(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("ts@example.com")
	_ = u.SetPassword("s3cret_pass")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.GetUser(ctx, api.GetUserRequestObject{})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.GetUser200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.Registered == nil {
		t.Fatal("registered field is missing")
	}

	ts := r.Registered.Format("2006-01-02T15:04:05Z07:00")

	// Must end with "Z" (UTC), not a local timezone offset
	if !strings.HasSuffix(ts, "Z") {
		t.Errorf("registered timestamp not in UTC: %s", ts)
	}

	// Must NOT contain nanoseconds (no "." in the seconds portion)
	if strings.Contains(ts, ".") {
		t.Errorf("registered timestamp contains sub-second precision: %s", ts)
	}
}

func TestConnectionMessages_ServerConversation(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	conn := irc.NewConnection("irc://irc.libera.chat", u)
	u.AddConnection(conn)

	// Create server conversation with empty ID (Perl behavior)
	serverConv := core.NewConversationWithID("", conn.Name(), conn)
	conn.AddConversation(serverConv)

	// Save a message to the server conversation
	_ = backend.SaveMessage(serverConv, core.Message{
		From:      "server",
		Message:   "Welcome to libera",
		Type:      "notice",
		Timestamp: 1700000000,
	})

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)
	resp, err := h.ConnectionMessages(ctx, api.ConnectionMessagesRequestObject{
		ConnectionId: conn.ID(),
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.ConnectionMessages200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	if r.Messages == nil || len(*r.Messages) == 0 {
		t.Error("Expected server messages from ConnectionMessages endpoint")
	}
}

func TestCreateConnection_ChannelAutoJoin(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	// Create connection with URL path containing a channel
	resp, err := h.CreateConnection(ctx, api.CreateConnectionRequestObject{
		Body: &api.CreateConnectionJSONRequestBody{
			Url: "irc://irc.libera.chat/%23convos",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.CreateConnection200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	// The connection should exist
	conn := u.GetConnection(r.ConnectionId)
	if conn == nil {
		t.Fatal("Connection not created")
	}

	// Should have auto-created conversation for #convos
	conv := conn.GetConversation("#convos")
	if conv == nil {
		t.Error("Expected auto-created conversation #convos from URL path")
	}
}

func TestCreateConnection_ConversationIdParam(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	convID := "#mychannel"
	resp, err := h.CreateConnection(ctx, api.CreateConnectionRequestObject{
		Body: &api.CreateConnectionJSONRequestBody{
			Url:            "irc://irc.libera.chat",
			ConversationId: &convID,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.CreateConnection200JSONResponse)
	if !ok {
		t.Fatalf("Unexpected response type: %T", resp)
	}

	conn := u.GetConnection(r.ConnectionId)
	if conn == nil {
		t.Fatal("Connection not created")
	}

	conv := conn.GetConversation("#mychannel")
	if conv == nil {
		t.Error("Expected auto-created conversation #mychannel from conversation_id param")
	}
}

func TestRegisterUser_AutoConnect(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	c.Settings().SetDefaultConnection("irc://irc.libera.chat/%23convos")

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	resp, err := h.RegisterUser(ctx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    openapi_types.Email("newuser@example.com"),
			Password: "s3cret_password",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.RegisterUser200JSONResponse)
	if !ok {
		t.Fatalf("Expected RegisterUser200JSONResponse, got %T", resp)
	}

	// Should have auto-created a connection
	if r.Connections == nil || len(*r.Connections) == 0 {
		t.Fatal("Expected auto-created connection from default_connection setting")
	}

	// Should have auto-created conversation for #convos from URL path
	if r.Conversations == nil || len(*r.Conversations) == 0 {
		t.Error("Expected auto-created conversation #convos from default_connection URL path")
	}

	found := false
	if r.Conversations != nil {
		for _, conv := range *r.Conversations {
			if conv.ConversationId == "#convos" {
				found = true
			}
		}
	}
	if !found {
		t.Error("Expected conversation #convos in response")
	}
}

func TestUpdateSettings_AutoCreateProfile(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("admin@example.com")
	u.GiveRole("admin")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	defaultConn := "irc://irc.libera.chat"
	_, err := h.UpdateSettings(ctx, api.UpdateSettingsRequestObject{
		Body: &api.UpdateSettingsJSONRequestBody{
			DefaultConnection: &defaultConn,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	// Should have auto-created a connection profile
	profiles, err := backend.LoadConnectionProfiles()
	if err != nil {
		t.Fatalf("Failed to load profiles: %v", err)
	}

	found := false
	for _, p := range profiles {
		if p.ID == testServer {
			found = true
			if !p.IsDefault {
				t.Error("Auto-created profile should be marked as default")
			}
		}
	}
	if !found {
		t.Error("Expected auto-created connection profile 'irc-libera'")
	}
}

func TestCreateConnection_AutoCreateProfile(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	_, err := h.CreateConnection(ctx, api.CreateConnectionRequestObject{
		Body: &api.CreateConnectionJSONRequestBody{
			Url: "irc://irc.libera.chat",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	// Should have auto-created a connection profile
	profiles, err := backend.LoadConnectionProfiles()
	if err != nil {
		t.Fatalf("Failed to load profiles: %v", err)
	}

	found := false
	for _, p := range profiles {
		if p.ID == testServer {
			found = true
			if !p.SkipQueue {
				t.Error("Auto-created profile from CreateConnection should have skip_queue=true")
			}
		}
	}
	if !found {
		t.Error("Expected auto-created connection profile 'irc-libera'")
	}
}

// Category 4 tests: error handling differences.

// errItem is a helper to extract the first error item from an ErrResponse.
type errItem struct {
	Message string  `json:"message"`
	Path    *string `json:"path,omitempty"`
}

type errBody struct {
	Errors []errItem `json:"errors"`
}

func parseErrResponse(t *testing.T, body api.Error) errBody {
	t.Helper()
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("Failed to marshal error body: %v", err)
	}
	var result errBody
	if err := json.Unmarshal(raw, &result); err != nil {
		t.Fatalf("Failed to unmarshal error body: %v", err)
	}
	return result
}

func TestErrorResponse_PathField(t *testing.T) {
	t.Parallel()
	resp := ErrResponse("test error")

	parsed := parseErrResponse(t, resp)
	if len(parsed.Errors) == 0 {
		t.Fatal("Expected at least one error item")
	}
	if parsed.Errors[0].Path == nil {
		t.Error("Error path field is missing — Perl always returns path: \"/\"")
	} else if *parsed.Errors[0].Path != "/" {
		t.Errorf("Error path: got %q, want \"/\"", *parsed.Errors[0].Path)
	}
}

func TestLoginUser_FailureStatusCode(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("test@example.com")
	_ = u.SetPassword("s3cret_pass")
	_ = u.Save()

	req := httptest.NewRequest("POST", "/api/user/login", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	resp, err := h.LoginUser(ctx, api.LoginUserRequestObject{
		Body: &api.LoginUserJSONRequestBody{
			Email:    "test@example.com",
			Password: "wrong_password",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	// Perl returns 400 for login failure, not 401
	r, ok := resp.(api.LoginUser400JSONResponse)
	if !ok {
		t.Fatalf("Expected LoginUser400JSONResponse, got %T", resp)
	}

	parsed := parseErrResponse(t, api.Error(r.BadRequestJSONResponse))
	if len(parsed.Errors) == 0 {
		t.Fatal("Expected error message")
	}
	if parsed.Errors[0].Message != "Invalid email or password." {
		t.Errorf("Login error message: got %q, want %q", parsed.Errors[0].Message, "Invalid email or password.")
	}
}

func TestRegisterUser_ClosedStatusCode(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	// Create first user so registration is "closed"
	u, _ := c.User("admin@example.com")
	_ = u.SetPassword("s3cret_pass!")
	_ = u.Save()

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	resp, err := h.RegisterUser(ctx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    openapi_types.Email("newuser@example.com"),
			Password: "s3cret_password",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	// Perl returns 401 for registration closed, not 403
	r, ok := resp.(api.RegisterUser401JSONResponse)
	if !ok {
		t.Fatalf("Expected RegisterUser401JSONResponse, got %T", resp)
	}

	parsed := parseErrResponse(t, api.Error(r.UnauthorizedJSONResponse))
	if len(parsed.Errors) == 0 {
		t.Fatal("Expected error message")
	}
	if parsed.Errors[0].Message != "Convos registration is not open to public." {
		t.Errorf("Registration error message: got %q, want %q", parsed.Errors[0].Message, "Convos registration is not open to public.")
	}
}

func TestRegisterUser_ConflictMessage(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetOpenToPublic(true)
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	u, _ := c.User("existing@example.com")
	_ = u.SetPassword("s3cret_pass!")
	_ = u.Save()

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	resp, err := h.RegisterUser(ctx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    openapi_types.Email("existing@example.com"),
			Password: "s3cret_password",
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.RegisterUser401JSONResponse)
	if !ok {
		t.Fatalf("Expected RegisterUser401JSONResponse, got %T", resp)
	}

	parsed := parseErrResponse(t, api.Error(r.UnauthorizedJSONResponse))
	if len(parsed.Errors) == 0 {
		t.Fatal("Expected error message")
	}
	if parsed.Errors[0].Message != "Email is taken." {
		t.Errorf("Conflict error message: got %q, want %q", parsed.Errors[0].Message, "Email is taken.")
	}
}

func TestConversationMessages_NotFound(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	// Nonexistent connection should return 404
	resp, err := h.ConversationMessages(ctx, api.ConversationMessagesRequestObject{
		ConnectionId:   "irc-nonexistent",
		ConversationId: "#test",
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.ConversationMessages404JSONResponse); !ok {
		t.Fatalf("Expected ConversationMessages404JSONResponse, got %T", resp)
	}
}

func TestConnectionMessages_NotFound(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

	u, _ := c.User("test@example.com")
	_ = u.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, u)

	// Nonexistent connection should return 404
	resp, err := h.ConnectionMessages(ctx, api.ConnectionMessagesRequestObject{
		ConnectionId: "irc-nonexistent",
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.ConnectionMessages404JSONResponse); !ok {
		t.Fatalf("Expected ConnectionMessages404JSONResponse, got %T", resp)
	}
}

func TestInviteUser_GeneratesValidToken(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	admin, _ := c.User("admin@example.com")
	admin.GiveRole("admin")
	_ = admin.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
	resp, err := h.InviteUser(ctx, api.InviteUserRequestObject{
		Email: "newuser@example.com",
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.InviteUser200JSONResponse)
	if !ok {
		t.Fatalf("Expected InviteUser200JSONResponse, got %T", resp)
	}

	if r.Existing != nil && *r.Existing {
		t.Error("Expected existing=false for new user")
	}
	if r.Expires == nil {
		t.Error("Expected expires to be set")
	}

	// Parse URL and verify query params
	u, err := url.Parse(r.Url)
	if err != nil {
		t.Fatalf("Failed to parse invite URL: %v", err)
	}
	if u.Query().Get("email") != "newuser@example.com" {
		t.Errorf("URL email: got %q, want %q", u.Query().Get("email"), "newuser@example.com")
	}
	if u.Query().Get("exp") == "" {
		t.Error("URL exp is empty")
	}
	if u.Query().Get("token") == "" {
		t.Error("URL token is empty")
	}
	// Token should be 40-char hex (HMAC-SHA1)
	if len(u.Query().Get("token")) != 40 {
		t.Errorf("Token length: got %d, want 40", len(u.Query().Get("token")))
	}
}

func TestInviteUser_ExistingUser(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	admin, _ := c.User("admin@example.com")
	admin.GiveRole("admin")
	_ = admin.Save()

	target, _ := c.User("existing@example.com")
	_ = target.SetPassword("old_password!")
	_ = target.Save()

	ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
	resp, err := h.InviteUser(ctx, api.InviteUserRequestObject{
		Email: "existing@example.com",
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.InviteUser200JSONResponse)
	if !ok {
		t.Fatalf("Expected InviteUser200JSONResponse, got %T", resp)
	}

	if r.Existing == nil || !*r.Existing {
		t.Error("Expected existing=true for existing user")
	}
}

func TestRegisterUser_WithInviteToken(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	// Create existing user so registration is "closed"
	admin, _ := c.User("admin@example.com")
	admin.GiveRole("admin")
	_ = admin.Save()

	// Generate invite for new user
	ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
	inviteResp, _ := h.InviteUser(ctx, api.InviteUserRequestObject{
		Email: "newuser@example.com",
	})
	invite, ok := inviteResp.(api.InviteUser200JSONResponse)
	if !ok {
		t.Fatalf("Expected InviteUser200JSONResponse, got %T", inviteResp)
	}
	inviteURL, _ := url.Parse(invite.Url)

	// Register with the invite token
	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	regCtx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	regCtx = context.WithValue(regCtx, core.CtxKeyResponseWriter, w)

	token := inviteURL.Query().Get("token")
	exp := inviteURL.Query().Get("exp")
	resp, err := h.RegisterUser(regCtx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    "newuser@example.com",
			Password: "s3cret_password",
			Token:    &token,
			Exp:      &exp,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.RegisterUser200JSONResponse); !ok {
		t.Fatalf("Expected RegisterUser200JSONResponse, got %T", resp)
	}

	if c.GetUser("newuser@example.com") == nil {
		t.Error("User should have been created")
	}
}

func TestRegisterUser_InvalidToken(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	admin, _ := c.User("admin@example.com")
	_ = admin.Save()

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	badToken := "0000000000000000000000000000000000000000"
	exp := "9999999999"
	resp, err := h.RegisterUser(ctx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    "newuser@example.com",
			Password: "s3cret_password",
			Token:    &badToken,
			Exp:      &exp,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	r, ok := resp.(api.RegisterUser401JSONResponse)
	if !ok {
		t.Fatalf("Expected RegisterUser401JSONResponse, got %T", resp)
	}

	parsed := parseErrResponse(t, api.Error(r.UnauthorizedJSONResponse))
	if len(parsed.Errors) == 0 {
		t.Fatal("Expected error message")
	}
	if parsed.Errors[0].Message != "invalid token. You have to ask your Convos admin for a new link" {
		t.Errorf("Error message: got %q", parsed.Errors[0].Message)
	}
}

func TestRegisterUser_ExpiredToken(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	admin, _ := c.User("admin@example.com")
	_ = admin.Save()

	// Generate a token with an expiration in the past
	expiredExp := int64(1000000000) // well in the past
	password := c.Settings().LocalSecret()
	token := inviteToken("newuser@example.com", expiredExp, password, "test-session-secret")

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	expStr := "1000000000"
	resp, err := h.RegisterUser(ctx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    "newuser@example.com",
			Password: "s3cret_password",
			Token:    &token,
			Exp:      &expStr,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.RegisterUser401JSONResponse); !ok {
		t.Fatalf("Expected RegisterUser401JSONResponse, got %T", resp)
	}
}

func TestRegisterUser_InviteExistingUser(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	c.Settings().SetSessionSecrets([]string{"test-session-secret"})
	c.Settings().SetLocalSecret("test-local-secret")
	store := sessions.NewCookieStore([]byte("test-session-secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	// Create admin and target user
	admin, _ := c.User("admin@example.com")
	admin.GiveRole("admin")
	_ = admin.Save()

	target, _ := c.User("target@example.com")
	_ = target.SetPassword("old_password!")
	_ = target.Save()

	// Generate invite for existing user
	ctx := context.WithValue(context.Background(), core.CtxKeyUser, admin)
	inviteResp, _ := h.InviteUser(ctx, api.InviteUserRequestObject{
		Email: "target@example.com",
	})
	invite, ok := inviteResp.(api.InviteUser200JSONResponse)
	if !ok {
		t.Fatalf("Expected InviteUser200JSONResponse, got %T", inviteResp)
	}
	inviteURL, _ := url.Parse(invite.Url)

	// Register (update) existing user with invite token
	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	regCtx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	regCtx = context.WithValue(regCtx, core.CtxKeyResponseWriter, w)

	token := inviteURL.Query().Get("token")
	exp := inviteURL.Query().Get("exp")
	resp, err := h.RegisterUser(regCtx, api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    "target@example.com",
			Password: "new_password!",
			Token:    &token,
			Exp:      &exp,
		},
	})
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.RegisterUser200JSONResponse); !ok {
		t.Fatalf("Expected RegisterUser200JSONResponse, got %T", resp)
	}

	// Verify password was updated
	updatedUser := c.GetUser("target@example.com")
	if updatedUser == nil {
		t.Fatal("User should still exist")
	}
	if !updatedUser.ValidatePassword("new_password!") {
		t.Error("Password should have been updated")
	}
	if updatedUser.ValidatePassword("old_password!") {
		t.Error("Old password should no longer work")
	}
}
