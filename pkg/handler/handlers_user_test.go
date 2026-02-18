package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
	"github.com/gorilla/sessions"
	openapi_types "github.com/oapi-codegen/runtime/types"
)

func TestRegisterUser_Validation(t *testing.T) {
	t.Parallel()
	store := sessions.NewCookieStore([]byte("secret"))

	tests := []struct {
		name           string
		email          string
		password       string
		openToPublic   bool
		existingUsers  int
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "Empty email",
			email:          "",
			password:       "password123",
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Email and password (min length 10) are required",
		},
		{
			name:           "Empty password",
			email:          "test@example.com",
			password:       "",
			expectedStatus: http.StatusBadRequest,
			expectedError:  "Email and password (min length 10) are required",
		},
		{
			name:           "Closed registration",
			email:          "test@example.com",
			password:       "password123",
			openToPublic:   false,
			existingUsers:  1,
			expectedStatus: http.StatusUnauthorized,
			expectedError:  "Convos registration is not open to public.",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			// Setup fresh core state for each subtest
			backend := test.NewMemoryBackend()
			c := core.New(core.WithBackend(backend))
			c.Settings().SetOpenToPublic(tt.openToPublic)
			h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

			if tt.existingUsers > 0 {
				u, _ := c.User("existing@example.com")
				if err := u.Save(); err != nil {
					t.Fatalf("Failed to save existing user: %v", err)
				}
			}

			req := httptest.NewRequest("POST", "/api/user/register", nil)
			w := httptest.NewRecorder()
			ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
			ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

			request := api.RegisterUserRequestObject{
				Body: &api.RegisterUserJSONRequestBody{
					Email:    openapi_types.Email(tt.email),
					Password: tt.password,
				},
			}

			resp, err := h.RegisterUser(ctx, request)
			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}

			var errors *[]struct {
				Message string  `json:"message"`
				Path    *string `json:"path,omitempty"`
			}
			switch r := resp.(type) {
			case api.RegisterUser400JSONResponse:
				if tt.expectedStatus != 400 {
					t.Errorf("Expected status %d, got 400", tt.expectedStatus)
				}
				errors = r.Errors
			case api.RegisterUser401JSONResponse:
				if tt.expectedStatus != 401 {
					t.Errorf("Expected status %d, got 401", tt.expectedStatus)
				}
				errors = r.Errors
			case api.RegisterUser500JSONResponse:
				if tt.expectedStatus != 500 {
					t.Errorf("Expected status %d, got 500", tt.expectedStatus)
				}
				errors = r.Errors
			default:
				t.Errorf("Unexpected response type %T", resp)
			}

			if errors != nil && (*errors)[0].Message != tt.expectedError {
				t.Errorf("Expected error %q, got %q", tt.expectedError, (*errors)[0].Message)
			}
		})
	}
}

func TestRegisterUser_FirstUserIsAdmin(t *testing.T) {
	t.Parallel()
	backend := test.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, auth.NewLocalAuthenticator(c), store, nil)

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), core.CtxKeyRequest, req)
	ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)

	request := api.RegisterUserRequestObject{
		Body: &api.RegisterUserJSONRequestBody{
			Email:    openapi_types.Email("admin@example.com"),
			Password: "password123",
		},
	}

	resp, err := h.RegisterUser(ctx, request)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if _, ok := resp.(api.RegisterUser200JSONResponse); !ok {
		t.Fatalf("Expected 200 response, got %T", resp)
	}

	user := c.GetUser("admin@example.com")
	if user == nil {
		t.Fatal("User not found in core")
	}

	if !user.HasRole("admin") {
		t.Error("First registered user should have admin role")
	}
}
