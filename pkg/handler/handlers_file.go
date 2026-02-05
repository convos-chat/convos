package handler

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"mime"
	"path/filepath"
	"time"

	"github.com/convos-chat/convos/pkg/api"
)

var ErrUploadFail = errors.New("upload error")

// GetFiles implements api.StrictServerInterface.
func (h *Handler) GetFiles(ctx context.Context, request api.GetFilesRequestObject) (api.GetFilesResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	files, err := h.Core.Backend().LoadFiles(user)
	if err != nil {
		return nil, err
	}

	res := make([]struct {
		Id    string    `json:"id"`
		Name  string    `json:"name"`
		Saved time.Time `json:"saved"`
		Size  int       `json:"size"`
	}, len(files))
	for i, f := range files {
		res[i] = struct {
			Id    string    `json:"id"`
			Name  string    `json:"name"`
			Saved time.Time `json:"saved"`
			Size  int       `json:"size"`
		}{
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
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	// The oapi-codegen gives us a multipart.Reader in request.Body
	if request.Body == nil {
		return nil, fmt.Errorf("request body is nil: %w", ErrUploadFail)
	}

	var savedFiles []struct {
		Ext      string    `json:"ext"`
		Filename string    `json:"filename"`
		Id       string    `json:"id"`
		Saved    time.Time `json:"saved"`
		Uid      string    `json:"uid"`
		Url      string    `json:"url"`
	}

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

		content, err := io.ReadAll(part)
		if err != nil {
			return nil, err
		}

		f, err := h.Core.Backend().SaveFile(user, part.FileName(), content)
		if err != nil {
			return nil, err
		}

		savedFiles = append(savedFiles, struct {
			Ext      string    `json:"ext"`
			Filename string    `json:"filename"`
			Id       string    `json:"id"`
			Saved    time.Time `json:"saved"`
			Uid      string    `json:"uid"`
			Url      string    `json:"url"`
		}{
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
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	if err := h.Core.Backend().DeleteFile(user, request.Fid); err != nil {
		return nil, err
	}

	return api.DeleteFiles200JSONResponse{}, nil
}

// GetFile implements api.StrictServerInterface.
func (h *Handler) GetFile(ctx context.Context, request api.GetFileRequestObject) (api.GetFileResponseObject, error) {
	user := h.GetUserFromCtx(ctx)
	if user == nil {
		return nil, ErrUnauthorized
	}
	content, filename, err := h.Core.Backend().GetFile(user, request.Fid)
	if err != nil {
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
