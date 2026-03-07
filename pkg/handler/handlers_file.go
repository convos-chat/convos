package handler

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"mime"
	"path/filepath"
	"strings"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/core"
)

// unsafeUploadMIMEPrefixes lists MIME type prefixes that can execute scripts
// in a browser when served inline. Files with these types are rejected at
// upload time.
var unsafeUploadMIMEPrefixes = []string{
	"text/html",
	"image/svg",
	"text/xml",
	"application/xml",
	"application/xhtml",
	"application/javascript",
	"text/javascript",
}

func isUnsafeMIME(ct string) bool {
	mimeType, _, _ := mime.ParseMediaType(ct)
	mimeType = strings.ToLower(mimeType)
	for _, prefix := range unsafeUploadMIMEPrefixes {
		if strings.HasPrefix(mimeType, prefix) {
			return true
		}
	}
	return false
}

var (
	ErrUploadFail     = errors.New("upload error")
	ErrUploadTooLarge = errors.New("file exceeds the maximum upload size")
)

// GetFiles implements api.StrictServerInterface.
func (h *Handler) GetFiles(ctx context.Context, request api.GetFilesRequestObject) (api.GetFilesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	files, err := h.Core.Backend.LoadFiles(user)
	if err != nil {
		return nil, err
	}

	type fileListEntry = struct {
		Id    string    `json:"id"`
		Name  string    `json:"name"`
		Saved time.Time `json:"saved"`
		Size  int       `json:"size"`
	}

	res := make([]fileListEntry, len(files))
	for i, f := range files {
		res[i] = fileListEntry{
			Id:    f.ID,
			Name:  f.Name,
			Saved: time.Unix(f.TS, 0).UTC(),
			Size:  int(f.Size),
		}
	}

	return api.GetFiles200JSONResponse{Files: &res}, nil
}

// UploadFile implements api.StrictServerInterface.
func (h *Handler) UploadFile(ctx context.Context, request api.UploadFileRequestObject) (api.UploadFileResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	// The oapi-codegen gives us a multipart.Reader in request.Body
	if request.Body == nil {
		return nil, fmt.Errorf("request body is nil: %w", ErrUploadFail)
	}

	type uploadedFileEntry = struct {
		Ext      string    `json:"ext"`
		Filename string    `json:"filename"`
		Id       string    `json:"id"`
		Saved    time.Time `json:"saved"`
		Uid      string    `json:"uid"`
		Url      string    `json:"url"`
	}

	var savedFiles []uploadedFileEntry

	for {
		part, err := request.Body.NextPart()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, err
		}

		if part.FormName() != "file" {
			continue
		}

		maxSize := h.MaxUploadSize
		if maxSize <= 0 {
			maxSize = 40_000_000
		}
		limited := io.LimitReader(part, maxSize+1)
		content, err := io.ReadAll(limited)
		if err != nil {
			return nil, err
		}
		if int64(len(content)) > maxSize {
			return nil, fmt.Errorf("%w: %d bytes exceeds limit of %d", ErrUploadTooLarge, len(content), maxSize)
		}

		filename := part.FileName()
		ext := filepath.Ext(filename)
		ct := mime.TypeByExtension(ext)
		if ct == "" {
			ct = "application/octet-stream"
		}
		if isUnsafeMIME(ct) {
			return nil, fmt.Errorf("file type %q is not allowed: %w", ct, ErrUploadFail)
		}

		f, err := h.Core.Backend.SaveFile(user, filename, content)
		if err != nil {
			return nil, err
		}

		savedFiles = append(savedFiles, uploadedFileEntry{
			Ext:      filepath.Ext(f.Name),
			Filename: f.Name,
			Id:       f.ID,
			Saved:    time.Unix(f.TS, 0).UTC(),
			Uid:      user.ID(),
			Url:      h.makeAbsoluteURL("/api/files/" + user.ID() + "/" + f.ID),
		})
	}

	return api.UploadFile200JSONResponse{Files: &savedFiles}, nil
}

// DeleteFiles implements api.StrictServerInterface.
func (h *Handler) DeleteFiles(ctx context.Context, request api.DeleteFilesRequestObject) (api.DeleteFilesResponseObject, error) {
	user, err := h.requireUser(ctx)
	if err != nil {
		return nil, err
	}
	if err := h.Core.Backend.DeleteFile(user, request.Fid); err != nil {
		return nil, err
	}

	return api.DeleteFiles200JSONResponse{}, nil
}

// GetFile implements api.StrictServerInterface.
func (h *Handler) GetFile(ctx context.Context, request api.GetFileRequestObject) (api.GetFileResponseObject, error) {
	user := h.Core.GetUser(request.Uid)
	if user == nil {
		return api.GetFile404JSONResponse{}, nil
	}
	content, filename, err := h.Core.Backend.GetFile(user, request.Fid)
	if err != nil {
		if errors.Is(err, core.ErrFileNotFound) {
			return api.GetFile404JSONResponse{}, nil
		}
		return nil, err
	}

	ct := mime.TypeByExtension(filepath.Ext(filename))
	if ct == "" {
		ct = "application/octet-stream"
	}

	return api.GetFile200AsteriskResponse{
		Body:          bytes.NewReader(content),
		ContentLength: int64(len(content)),
		ContentType:   ct,
	}, nil
}
