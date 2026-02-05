package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
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
			backend := core.NewMemoryBackend()
			c := core.New(core.WithBackend(backend))
			c.Settings().SetOpenToPublic(tt.openToPublic)
			h := NewHandler(c, store, nil)

			if tt.existingUsers > 0 {
				u, _ := c.User("existing@example.com")
				if err := u.Save(); err != nil {
					t.Fatalf("Failed to save existing user: %v", err)
				}
			}

			req := httptest.NewRequest("POST", "/api/user/register", nil)
			w := httptest.NewRecorder()
			ctx := context.WithValue(context.Background(), CtxKeyRequest, req)
			ctx = context.WithValue(ctx, CtxKeyResponseWriter, w)

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

			if r, ok := resp.(api.RegisterUserdefaultJSONResponse); ok {
				if r.StatusCode != tt.expectedStatus {
					t.Errorf("Expected status %d, got %d", tt.expectedStatus, r.StatusCode)
				}
				if r.Body.Errors != nil && (*r.Body.Errors)[0].Message != tt.expectedError {
					t.Errorf("Expected error %q, got %q", tt.expectedError, (*r.Body.Errors)[0].Message)
				}
			} else {
				t.Errorf("Unexpected response type: %T", resp)
			}
		})
	}
}

func TestRegisterUser_FirstUserIsAdmin(t *testing.T) {
	t.Parallel()
	backend := core.NewMemoryBackend()
	c := core.New(core.WithBackend(backend))
	store := sessions.NewCookieStore([]byte("secret"))
	h := NewHandler(c, store, nil)

	req := httptest.NewRequest("POST", "/api/user/register", nil)
	w := httptest.NewRecorder()
	ctx := context.WithValue(context.Background(), CtxKeyRequest, req)
	ctx = context.WithValue(ctx, CtxKeyResponseWriter, w)

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
