package core_test

import (
	"bytes"
	"testing"

	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/test"
)

func TestMemoryBackend_Search(t *testing.T) {
	t.Parallel()
	b := test.NewMemoryBackend()
	c := core.New(core.WithBackend(b))
	user := core.NewUser("test@example.com", c)
	conn := newTestConnection("irc://irc.libera.chat", user)
	conv := core.NewConversation("#test", conn)
	user.AddConnection(conn)
	conn.AddConversation(conv)

	// Save some messages
	msgs := []core.Message{
		{From: "alice", Message: "Hello there", Type: "privmsg"},
		{From: "bob", Message: "Hi alice", Type: "privmsg"},
		{From: "alice", Message: "How is it going?", Type: "privmsg"},
	}
	for _, m := range msgs {
		if err := b.SaveMessage(conv, m); err != nil {
			t.Fatalf("SaveMessage failed: %v", err)
		}
	}
	// Need to save connection to backend so search can find conversations
	if err := b.SaveConnection(conn); err != nil {
		t.Fatalf("SaveConnection failed: %v", err)
	}

	t.Run("Match_Found", func(t *testing.T) {
		t.Parallel()
		res, err := b.SearchMessages(user, core.MessageQuery{Match: "hello", Limit: 10})
		if err != nil {
			t.Fatalf("Search failed: %v", err)
		}
		if len(res.Messages) != 1 {
			t.Errorf("Expected 1 match, got %d", len(res.Messages))
		}
		if res.Messages[0].Message != "Hello there" {
			t.Errorf("Unexpected message: %q", res.Messages[0].Message)
		}
	})

	t.Run("Match_CaseInsensitive", func(t *testing.T) {
		t.Parallel()
		res, _ := b.SearchMessages(user, core.MessageQuery{Match: "ALICE", Limit: 10})
		if len(res.Messages) != 1 {
			t.Errorf("Expected 1 match, got %d", len(res.Messages))
		}
	})

	t.Run("No_Match", func(t *testing.T) {
		t.Parallel()
		res, _ := b.SearchMessages(user, core.MessageQuery{Match: "nomatch", Limit: 10})
		if len(res.Messages) != 0 {
			t.Errorf("Expected 0 matches, got %d", len(res.Messages))
		}
	})
}

func TestMemoryBackend_Files(t *testing.T) {
	t.Parallel()

	setup := func() (*test.MemoryBackend, *core.User) {
		b := test.NewMemoryBackend()
		c := core.New(core.WithBackend(b))
		user := core.NewUser("test@example.com", c)
		return b, user
	}

	content := []byte("file content")
	name := "test.txt"

	t.Run("SaveAndLoad", func(t *testing.T) {
		t.Parallel()
		b, user := setup()
		f, err := b.SaveFile(user, name, content)
		if err != nil {
			t.Fatalf("SaveFile failed: %v", err)
		}
		if f.Name != name {
			t.Errorf("Expected name %q, got %q", name, f.Name)
		}

		files, _ := b.LoadFiles(user)
		if len(files) != 1 {
			t.Errorf("Expected 1 file, got %d", len(files))
		}

		gotContent, gotName, err := b.GetFile(user, f.ID)
		if err != nil {
			t.Fatalf("GetFile failed: %v", err)
		}
		if gotName != name {
			t.Errorf("Expected name %q, got %q", name, gotName)
		}
		if !bytes.Equal(gotContent, content) {
			t.Errorf("Expected content %q, got %q", string(content), string(gotContent))
		}
	})

	t.Run("DeleteFile", func(t *testing.T) {
		t.Parallel()
		b, user := setup()
		// Setup: create a file first
		f, err := b.SaveFile(user, name, content)
		if err != nil {
			t.Fatalf("Setup: SaveFile failed: %v", err)
		}

		files, _ := b.LoadFiles(user)
		if len(files) == 0 {
			t.Fatalf("LoadFiles returned 0 files, expected at least 1")
		}
		fid := files[0].ID
		if fid != f.ID {
			t.Errorf("Expected file ID %q, got %q", f.ID, fid)
		}

		err = b.DeleteFile(user, fid)
		if err != nil {
			t.Fatalf("DeleteFile failed: %v", err)
		}

		filesAfter, _ := b.LoadFiles(user)
		if len(filesAfter) != 0 {
			t.Error("File metadata should have been deleted")
		}

		_, _, err = b.GetFile(user, fid)
		if err == nil {
			t.Error("GetFile should fail for deleted file")
		}
	})
}
