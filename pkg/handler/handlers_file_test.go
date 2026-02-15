package handler

import (
	"bytes"
	"context"
	"errors"
	"io"
	"mime/multipart"
	"testing"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/auth"
	"github.com/convos-chat/convos/pkg/core"
)

func TestFileHandlers(t *testing.T) {
	t.Parallel()

	setup := func() (*core.Core, *Handler, *core.User) {
		backend := core.NewMemoryBackend()
		c := core.New(core.WithBackend(backend))
		h := NewHandler(c, auth.NewLocalAuthenticator(c), nil, nil)

		user, _ := c.User("test@example.com")
		_ = user.Save()
		return c, h, user
	}

	t.Run("GetFiles_Empty", func(t *testing.T) {
		t.Parallel()
		_, h, user := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		resp, _ := h.GetFiles(ctx, api.GetFilesRequestObject{})
		if r, ok := resp.(api.GetFiles200JSONResponse); ok {
			if len(*r.Files) != 0 {
				t.Errorf("Expected 0 files, got %d", len(*r.Files))
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("GetFiles_Unauthorized", func(t *testing.T) {
		t.Parallel()
		_, h, _ := setup()
		resp, _ := h.GetFiles(context.Background(), api.GetFilesRequestObject{})
		if r, ok := resp.(api.GetFiles200JSONResponse); ok {
			if len(*r.Files) != 0 {
				t.Error("Expected 0 files for unauthorized access")
			}
		}
	})

	t.Run("GetFile_Success", func(t *testing.T) {
		t.Parallel()
		c, h, user := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)
		content := []byte("hello world")
		f, _ := c.Backend().SaveFile(user, "test.txt", content)

		resp, _ := h.GetFile(ctx, api.GetFileRequestObject{Uid: user.ID(), Fid: f.ID})
		if r, ok := resp.(api.GetFile200AsteriskResponse); ok {
			if r.ContentType != "text/plain; charset=utf-8" {
				t.Errorf("Expected text/plain, got %q", r.ContentType)
			}
			got, _ := io.ReadAll(r.Body)
			if string(got) != string(content) {
				t.Errorf("Expected %q, got %q", string(content), string(got))
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("UploadFile_ExceedsMaxSize", func(t *testing.T) {
		t.Parallel()
		_, h, user := setup()
		h.MaxUploadSize = 100 // 100 bytes
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)

		var buf bytes.Buffer
		w := multipart.NewWriter(&buf)
		part, _ := w.CreateFormFile("file", "big.txt")
		if _, err := part.Write(bytes.Repeat([]byte("x"), 200)); err != nil {
			t.Fatalf("Failed to write to multipart part: %v", err)
		}

		w.Close()

		reader := multipart.NewReader(&buf, w.Boundary())
		_, err := h.UploadFile(ctx, api.UploadFileRequestObject{Body: reader})
		if err == nil {
			t.Fatal("Expected error for oversized upload")
		}
		if !errors.Is(err, ErrUploadTooLarge) {
			t.Errorf("Expected ErrUploadTooLarge, got: %v", err)
		}
	})

	t.Run("UploadFile_WithinMaxSize", func(t *testing.T) {
		t.Parallel()
		_, h, user := setup()
		h.MaxUploadSize = 1000
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)

		var buf bytes.Buffer
		w := multipart.NewWriter(&buf)
		part, _ := w.CreateFormFile("file", "small.txt")
		if _, err := part.Write([]byte("hello")); err != nil {
			t.Fatalf("Failed to write to multipart part: %v", err)
		}
		w.Close()

		reader := multipart.NewReader(&buf, w.Boundary())
		resp, err := h.UploadFile(ctx, api.UploadFileRequestObject{Body: reader})
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}
		if r, ok := resp.(api.UploadFile200JSONResponse); ok {
			if len(*r.Files) != 1 {
				t.Errorf("Expected 1 file, got %d", len(*r.Files))
			}
		} else {
			t.Errorf("Unexpected response type: %T", resp)
		}
	})

	t.Run("DeleteFile", func(t *testing.T) {
		t.Parallel()
		c, h, user := setup()
		ctx := context.WithValue(context.Background(), core.CtxKeyUser, user)

		// Create a file to delete specifically for this test
		f, err := c.Backend().SaveFile(user, "delete_me.txt", []byte("delete me"))
		if err != nil {
			t.Fatalf("Failed to create file for deletion: %v", err)
		}
		fid := f.ID

		_, err = h.DeleteFiles(ctx, api.DeleteFilesRequestObject{Fid: fid})
		if err != nil {
			t.Fatalf("DeleteFiles failed: %v", err)
		}

		// Verify file is gone - LoadFiles might return other files, so we check GetFile
		_, _, err = c.Backend().GetFile(user, fid)
		if err == nil {
			t.Error("GetFile should fail for deleted file")
		}
	})
}
