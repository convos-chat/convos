// Package storage implements a file-based backend for Convos, compatible with Perl's Convos::Core::Backend::File.
package storage

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/convos-chat/convos/pkg/core"
)

// Message type constants (matching Perl Convos conventions).
const (
	msgTypePrivmsg = "private"
	msgTypeNotice  = "notice"
	msgTypeAction  = "action"
)

// FileBackend implements core.Backend using file-based storage.
// This is compatible with the Perl Convos::Core::Backend::File implementation.
type FileBackend struct {
	mu   sync.RWMutex
	home string
}

// NewFileBackend creates a new file-based backend.
func NewFileBackend(home string) *FileBackend {
	return &FileBackend{home: home}
}

// Home returns the home directory.
func (b *FileBackend) Home() string {
	return b.home
}

// userDir returns the directory for a user.
func (b *FileBackend) userDir(userID string) string {
	return filepath.Join(b.home, userID)
}

// userFile returns the path to a user's settings file.
func (b *FileBackend) userFile(userID string) string {
	return filepath.Join(b.userDir(userID), "user.json")
}

// connectionDir returns the directory for a connection.
func (b *FileBackend) connectionDir(userID, connectionID string) string {
	return filepath.Join(b.userDir(userID), connectionID)
}

// connectionFile returns the path to a connection's settings file.
func (b *FileBackend) connectionFile(userID, connectionID string) string {
	return filepath.Join(b.connectionDir(userID, connectionID), "connection.json")
}

// logFile returns the path to a conversation log file.
// Perl stores each conversation in its own monthly log file:
//   - Server/connection messages (empty convID): YYYY/MM.log
//   - Channel/private messages: YYYY/MM/convID.log
func (b *FileBackend) logFile(userID, connectionID, convID string, t time.Time) string {
	ym := fmt.Sprintf("%d/%02d", t.Year(), t.Month())
	if convID == "" {
		return filepath.Join(b.connectionDir(userID, connectionID), ym+".log")
	}
	// Escape '/' in conversation IDs (e.g. for queries with slashes), matching Perl behavior
	convID = strings.ReplaceAll(convID, "/", "%2F")
	return filepath.Join(b.connectionDir(userID, connectionID), ym, convID+".log")
}

// notificationsFile returns the path to a user's notifications file.
func (b *FileBackend) notificationsFile(userID string) string {
	return filepath.Join(b.userDir(userID), "notifications.log")
}

// LoadUsers returns all stored users.
func (b *FileBackend) LoadUsers() ([]core.UserData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	entries, err := os.ReadDir(b.home)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return []core.UserData{}, nil
		}
		return nil, err
	}

	var users []core.UserData
	emailRE := regexp.MustCompile(`.\@.`)

	for _, entry := range entries {
		if !entry.IsDir() || !emailRE.MatchString(entry.Name()) {
			continue
		}

		userFile := b.userFile(entry.Name())
		data, err := os.ReadFile(userFile)
		if err != nil {
			continue // Skip if user.json doesn't exist
		}

		var userData core.UserData
		if err := json.Unmarshal(data, &userData); err != nil {
			continue
		}

		// Set registered from file mtime if not set
		if userData.Registered.IsZero() {
			if info, err := os.Stat(userFile); err == nil {
				userData.Registered = info.ModTime()
			}
		}

		users = append(users, userData)
	}

	// Sort by registration date then email
	sort.Slice(users, func(i, j int) bool {
		if users[i].Registered.Equal(users[j].Registered) {
			return users[i].Email < users[j].Email
		}
		return users[i].Registered.Before(users[j].Registered)
	})

	return users, nil
}

// SaveUser stores a user.
func (b *FileBackend) SaveUser(user *core.User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	userDir := b.userDir(user.ID())
	if err := os.MkdirAll(userDir, 0o755); err != nil {
		return err
	}

	data := user.ToData(true)
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}

	// Write to swap file first, then rename (atomic)
	userFile := b.userFile(user.ID())
	swapFile := filepath.Join(filepath.Dir(userFile), ".user.json.swap")

	if err := os.WriteFile(swapFile, jsonData, 0o600); err != nil {
		return err
	}

	return os.Rename(swapFile, userFile)
}

// DeleteUser removes a user and all their data.
func (b *FileBackend) DeleteUser(user *core.User) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	return os.RemoveAll(b.userDir(user.ID()))
}

// LoadConnections returns connections for a user.
func (b *FileBackend) LoadConnections(user *core.User) ([]core.ConnectionData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	userDir := b.userDir(user.ID())
	entries, err := os.ReadDir(userDir)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return []core.ConnectionData{}, nil
		}
		return nil, err
	}

	var connections []core.ConnectionData
	for _, entry := range entries {
		if !entry.IsDir() || !strings.HasPrefix(entry.Name(), "irc") {
			continue
		}

		connFile := b.connectionFile(user.ID(), entry.Name())
		data, err := os.ReadFile(connFile)
		if err != nil {
			continue
		}

		var connData core.ConnectionData
		if err := json.Unmarshal(data, &connData); err != nil {
			continue
		}

		// State should not be stored
		connData.State = ""
		connections = append(connections, connData)
	}

	return connections, nil
}

// SaveConnection stores a connection.
func (b *FileBackend) SaveConnection(conn core.Connection) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	connDir := b.connectionDir(conn.User().ID(), conn.ID())
	if err := os.MkdirAll(connDir, 0o755); err != nil {
		return err
	}

	data := conn.ToData(true)
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}

	connFile := b.connectionFile(conn.User().ID(), conn.ID())
	swapFile := filepath.Join(filepath.Dir(connFile), ".connection.json.swap")

	if err := os.WriteFile(swapFile, jsonData, 0o600); err != nil {
		return err
	}

	return os.Rename(swapFile, connFile)
}

// DeleteConnection removes a connection and its data.
func (b *FileBackend) DeleteConnection(conn core.Connection) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	return os.RemoveAll(b.connectionDir(conn.User().ID(), conn.ID()))
}

// logLineRE matches the Perl log format: "TIMESTAMP FLAG_BYTE REST_OF_LINE"
var logLineRE = regexp.MustCompile(`^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+\d+\s+(.*)$`)

// LoadMessages returns messages for a conversation.
func (b *FileBackend) LoadMessages(conv *core.Conversation, query core.MessageQuery) (core.MessageResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	limit := query.Limit
	if limit <= 0 || limit > 200 {
		limit = 60
	}

	result := core.MessageResult{
		End:      true,
		Messages: []core.Message{},
	}

	// When around is set, treat it as before if before is not set
	if query.Around != "" && query.Before == "" {
		query.Before = query.Around
	}

	now := time.Now().UTC()
	var before, after time.Time
	var incBy int // -1 = backward (newest first), 1 = forward (oldest first)

	hasBefore := query.Before != ""
	hasAfter := query.After != ""

	switch {
	case hasBefore && hasAfter:
		before, _ = time.Parse(time.RFC3339, query.Before)
		after, _ = time.Parse(time.RFC3339, query.After)
		incBy = 1
	case hasBefore:
		before, _ = time.Parse(time.RFC3339, query.Before)
		after = before.AddDate(-1, 0, 0)
		incBy = -1
	case hasAfter:
		after, _ = time.Parse(time.RFC3339, query.After)
		before = after.AddDate(1, 0, 0)
		future := now.AddDate(0, 1, 0)
		if before.After(future) {
			before = future
		}
		incBy = 1
	default:
		before = now.Add(10 * time.Second) // small buffer to include messages sent right now
		after = before.AddDate(-1, 0, 0)
		incBy = -1
	}

	userID := conv.Connection().User().ID()
	connID := conv.Connection().ID()
	convID := conv.ID()

	// Set cursor to starting point based on direction
	cursor := before
	if incBy > 0 {
		cursor = after
	}

	// Iterate through months in the appropriate direction
	var messages []core.Message
	for !cursor.Before(after) && !cursor.After(before.AddDate(0, 1, 0)) {
		// Check if cursor is within search range [after, before+1month]

		remaining := limit + 1 - len(messages)
		logFile := b.logFile(userID, connID, convID, cursor)

		var msgs []core.Message
		var err error
		if incBy > 0 {
			msgs, err = b.readLogFile(logFile, after, before, remaining)
		} else {
			msgs, err = b.readLogFileBackward(logFile, after, before, remaining)
		}

		if err == nil && len(msgs) > 0 {
			if incBy > 0 {
				messages = append(messages, msgs...)
			} else {
				messages = append(msgs, messages...)
			}
		}

		if len(messages) > limit {
			break
		}

		cursor = cursor.AddDate(0, incBy, 0)
	}

	// Trim to limit from the correct end based on direction
	if len(messages) > limit {
		if incBy > 0 {
			messages = messages[:limit]
		} else {
			messages = messages[len(messages)-limit:]
		}
		result.End = false
	}

	result.Messages = messages
	return result, nil
}

// readLogFile reads messages forward from a log file, up to limit.
// Used for forward iteration (incBy > 0). Since log files are chronological,
// stops early when timestamps exceed the before boundary.
func (b *FileBackend) readLogFile(path string, after, before time.Time, limit int) ([]core.Message, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var messages []core.Message
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()
		matches := logLineRE.FindStringSubmatch(line)
		if matches == nil {
			continue
		}

		ts, err := time.Parse("2006-01-02T15:04:05", matches[1])
		if err != nil {
			continue
		}

		// Strict inequality matching Perl: after < ts < before
		if !ts.After(after) || !ts.Before(before) {
			// Log files are chronological; if ts >= before, no more matches
			if !ts.Before(before) {
				break
			}
			continue
		}

		msg := b.parseMessageLine(matches[2])
		msg.Timestamp = ts.Unix()
		messages = append(messages, msg)

		if len(messages) >= limit {
			break
		}
	}

	return messages, scanner.Err()
}

// readLogFileBackward reads messages from the end of a log file, returning up
// to limit messages in chronological order.
func (b *FileBackend) readLogFileBackward(path string, after, before time.Time, limit int) ([]core.Message, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		return nil, err
	}
	size := info.Size()
	if size == 0 {
		return nil, nil
	}

	const chunkSize = 8192
	var messages []core.Message
	var remaining string
	offset := size
	done := false

	for offset > 0 && len(messages) < limit && !done {
		readSize := min(int64(chunkSize), offset)
		offset -= readSize

		buf := make([]byte, readSize)
		if _, err := file.ReadAt(buf, offset); err != nil {
			return messages, err
		}

		chunk := string(buf)
		lines := strings.Split(chunk, "\n")

		// The last element of this chunk may be the beginning of a line that
		// continues into the next (already-processed) chunk. Append the saved
		// remainder to complete it.
		lines[len(lines)-1] += remaining
		remaining = ""

		// If we haven't reached the start of the file, the first element is a
		// partial line — save it for the next iteration.
		if offset > 0 {
			remaining = lines[0]
			lines = lines[1:]
		}

		// Process lines in reverse (newest first within this chunk)
		for i := len(lines) - 1; i >= 0 && len(messages) < limit; i-- {
			line := lines[i]
			if line == "" {
				continue
			}

			matches := logLineRE.FindStringSubmatch(line)
			if matches == nil {
				continue
			}

			ts, err := time.Parse("2006-01-02T15:04:05", matches[1])
			if err != nil {
				continue
			}

			// Strict inequality: after < ts < before
			if !ts.After(after) || !ts.Before(before) {
				// Log files are chronological; reading backwards, if ts <= after
				// then all earlier lines are also <= after — stop scanning.
				if !ts.After(after) {
					done = true
					break
				}
				continue
			}

			msg := b.parseMessageLine(matches[2])
			msg.Timestamp = ts.Unix()
			messages = append(messages, msg)
		}
	}

	slices.Reverse(messages)

	return messages, nil
}

// parseMessageLine parses a message from log format.
func (b *FileBackend) parseMessageLine(line string) core.Message {
	msg := core.Message{Message: line}

	// <nick> message - private message
	if strings.HasPrefix(line, "<") {
		if idx := strings.Index(line, "> "); idx > 0 {
			msg.From = line[1:idx]
			msg.Message = line[idx+2:]
			msg.Type = msgTypePrivmsg
			return msg
		}
	}

	// -!- message - server message (check before -nick- notice)
	if strings.HasPrefix(line, "-!- ") {
		msg.Message = line[4:]
		msg.Type = msgTypeNotice
		msg.From = ""
		return msg
	}

	// -nick- message - notice (nick cannot start with !)
	if strings.HasPrefix(line, "-") && !strings.HasPrefix(line, "-!") {
		if idx := strings.Index(line[1:], "- "); idx > 0 {
			msg.From = line[1 : idx+1]
			msg.Message = line[idx+3:]
			msg.Type = msgTypeNotice
			return msg
		}
	}

	// * nick message - action
	if strings.HasPrefix(line, "* ") {
		parts := strings.SplitN(line[2:], " ", 2)
		if len(parts) == 2 {
			msg.From = parts[0]
			msg.Message = parts[1]
			msg.Type = msgTypeAction
			return msg
		}
	}

	msg.Type = msgTypeNotice
	return msg
}

// SaveMessage stores a message.
func (b *FileBackend) SaveMessage(conv *core.Conversation, msg core.Message) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	ts := time.Unix(msg.Timestamp, 0).UTC()
	if msg.Timestamp == 0 {
		ts = time.Now().UTC()
	}

	logFile := b.logFile(conv.Connection().User().ID(), conv.Connection().ID(), conv.ID(), ts)

	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(logFile), 0o700); err != nil {
		return err
	}

	file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer file.Close()

	// Format message (Perl format: "TIMESTAMP 0 MESSAGE")
	line := b.formatMessageLine(msg)
	_, err = fmt.Fprintf(file, "%s 0 %s\n", ts.Format("2006-01-02T15:04:05"), line)
	return err
}

// formatMessageLine formats a message for log storage.
func (b *FileBackend) formatMessageLine(msg core.Message) string {
	switch msg.Type {
	case msgTypePrivmsg:
		return fmt.Sprintf("<%s> %s", msg.From, msg.Message)
	case msgTypeNotice:
		if msg.From != "" {
			return fmt.Sprintf("-%s- %s", msg.From, msg.Message)
		}
		return fmt.Sprintf("-!- %s", msg.Message)
	case msgTypeAction:
		return fmt.Sprintf("* %s %s", msg.From, msg.Message)
	default:
		return msg.Message
	}
}

// DeleteMessages removes all messages for a conversation.
// This removes all log files for the connection.
func (b *FileBackend) DeleteMessages(conv *core.Conversation) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	connDir := b.connectionDir(conv.Connection().User().ID(), conv.Connection().ID())

	return filepath.WalkDir(connDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && strings.HasSuffix(d.Name(), ".log") {
			if err = os.Remove(path); err != nil {
				slog.Warn("Failed to delete log file", "path", path, "error", err)
			}
		}
		return nil
	})
}

// LoadNotifications returns notifications for a user.
func (b *FileBackend) LoadNotifications(user *core.User, query core.MessageQuery) (core.NotificationResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	limit := query.Limit
	if limit <= 0 || limit > 100 {
		limit = 40
	}

	result := core.NotificationResult{
		End:           true,
		Notifications: []core.Notification{},
	}

	notifFile := b.notificationsFile(user.ID())
	file, err := os.Open(notifFile)
	if err != nil {
		return result, nil // No notifications file is OK
	}
	defer file.Close()

	// Read all lines
	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	// Format: timestamp connection_id conversation_id <nick> message
	lineRE := regexp.MustCompile(`^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+)\s+(.*)$`)
	for i := len(lines) - 1; i >= 0 && len(result.Notifications) < limit; i-- {
		matches := lineRE.FindStringSubmatch(lines[i])
		if matches == nil {
			continue
		}

		ts, err := time.Parse("2006-01-02T15:04:05", matches[1])
		if err != nil {
			continue
		}

		msg := b.parseMessageLine(matches[4])
		notif := core.Notification{
			ConnectionID:   matches[2],
			ConversationID: matches[3],
			From:           msg.From,
			Message:        msg.Message,
			Type:           msg.Type,
			Timestamp:      ts.Unix(),
		}

		result.Notifications = append([]core.Notification{notif}, result.Notifications...)
	}

	return result, nil
}

// SaveNotification appends a notification to the user's notifications file.
func (b *FileBackend) SaveNotification(user *core.User, msg core.Notification) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	notifFile := b.notificationsFile(user.ID())
	if err := os.MkdirAll(filepath.Dir(notifFile), 0o755); err != nil {
		return err
	}

	file, err := os.OpenFile(notifFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer file.Close()

	ts := time.Unix(msg.Timestamp, 0).UTC()
	if msg.Timestamp == 0 {
		ts = time.Now().UTC()
	}

	// Format: timestamp connection_id conversation_id <nick> message
	coreMsg := core.Message{From: msg.From, Message: msg.Message, Type: msg.Type}
	line := b.formatMessageLine(coreMsg)
	_, err = fmt.Fprintf(file, "%s %s %s %s\n", ts.Format("2006-01-02T15:04:05"), msg.ConnectionID, msg.ConversationID, line)
	return err
}

// settingsFile returns the path to the settings file.
func (b *FileBackend) settingsFile() string {
	return filepath.Join(b.home, "settings.json")
}

// LoadSettings loads settings from disk.
func (b *FileBackend) LoadSettings() (core.SettingsData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	var data core.SettingsData
	// Defaults
	data.VideoService = "https://meet.jit.si/"
	raw, err := os.ReadFile(b.settingsFile())
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return data, nil
		}
		return data, err
	}

	if err := json.Unmarshal(raw, &data); err != nil {
		return data, err
	}
	return data, nil
}

// SaveSettings saves settings to disk.
func (b *FileBackend) SaveSettings(data core.SettingsData) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	if err := os.MkdirAll(b.home, 0o755); err != nil {
		return err
	}

	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}

	settingsFile := b.settingsFile()
	swapFile := filepath.Join(filepath.Dir(settingsFile), ".settings.json.swap")

	if err := os.WriteFile(swapFile, jsonData, 0o600); err != nil {
		return err
	}

	return os.Rename(swapFile, settingsFile)
}

func (b *FileBackend) profilesDir() string {
	return filepath.Join(b.home, "settings", "connections")
}

func (b *FileBackend) profileFile(id string) string {
	return filepath.Join(b.profilesDir(), id+".json")
}

// LoadConnectionProfiles returns all stored connection profiles.
func (b *FileBackend) LoadConnectionProfiles() ([]core.ConnectionProfileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	dir := b.profilesDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return []core.ConnectionProfileData{}, nil
		}
		return nil, err
	}

	profiles := make([]core.ConnectionProfileData, 0)
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			continue
		}

		var profile core.ConnectionProfileData
		if err := json.Unmarshal(data, &profile); err != nil {
			continue
		}
		if profile.ID == "" {
			profile.ID = strings.TrimSuffix(entry.Name(), ".json")
		}
		profiles = append(profiles, profile)
	}

	return profiles, nil
}

// SaveConnectionProfile stores a connection profile.
func (b *FileBackend) SaveConnectionProfile(profile core.ConnectionProfileData) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	dir := b.profilesDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	jsonData, err := json.MarshalIndent(profile, "", "  ")
	if err != nil {
		return err
	}

	file := b.profileFile(profile.ID)
	swapFile := filepath.Join(dir, "."+profile.ID+".json.swap")

	if err := os.WriteFile(swapFile, jsonData, 0o600); err != nil {
		return err
	}

	return os.Rename(swapFile, file)
}

// DeleteConnectionProfile removes a connection profile.
func (b *FileBackend) DeleteConnectionProfile(id string) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	return os.Remove(b.profileFile(id))
}

func (b *FileBackend) uploadDir(userID string) string {
	return filepath.Join(b.userDir(userID), "upload")
}

// uploadMeta is the JSON metadata stored alongside uploaded file content.
// Compatible with Perl's upload format: id.json (metadata) + id.data (content).
type uploadMeta struct {
	Filename string `json:"filename"`
	ID       string `json:"id"`
	Saved    string `json:"saved"`
}

// LoadFiles returns all files for a user.
func (b *FileBackend) LoadFiles(user *core.User) ([]core.FileData, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	dir := b.uploadDir(user.ID())
	entries, err := os.ReadDir(dir)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return []core.FileData{}, nil
		}
		return nil, err
	}

	var files []core.FileData
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		raw, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			continue
		}

		var meta uploadMeta
		if err := json.Unmarshal(raw, &meta); err != nil {
			continue
		}

		// Get size from the .data file
		var size int64
		dataPath := filepath.Join(dir, meta.ID+".data")
		if info, err := os.Stat(dataPath); err == nil {
			size = info.Size()
		}

		var ts int64
		if t, err := time.Parse(time.RFC3339, meta.Saved); err == nil {
			ts = t.Unix()
		}

		files = append(files, core.FileData{
			ID:   meta.ID,
			Name: meta.Filename,
			Size: size,
			TS:   ts,
		})
	}

	return files, nil
}

// SaveFile stores a file as id.json (metadata) + id.data (content),
// compatible with Perl's upload format.
func (b *FileBackend) SaveFile(user *core.User, name string, content []byte) (core.FileData, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	dir := b.uploadDir(user.ID())
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return core.FileData{}, err
	}

	id := fmt.Sprintf("%d-%s", time.Now().Unix(), strings.TrimSuffix(name, filepath.Ext(name)))
	now := time.Now().UTC()

	meta := uploadMeta{
		Filename: name,
		ID:       id,
		Saved:    now.Format(time.RFC3339),
	}

	metaJSON, err := json.MarshalIndent(meta, "", "  ")
	if err != nil {
		return core.FileData{}, err
	}

	if err := os.WriteFile(filepath.Join(dir, id+".json"), metaJSON, 0o600); err != nil {
		return core.FileData{}, err
	}

	if err := os.WriteFile(filepath.Join(dir, id+".data"), content, 0o600); err != nil {
		return core.FileData{}, err
	}

	return core.FileData{
		ID:   id,
		Name: name,
		Size: int64(len(content)),
		TS:   now.Unix(),
	}, nil
}

// DeleteFile removes a file (both metadata and content).
func (b *FileBackend) DeleteFile(user *core.User, id string) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	dir := b.uploadDir(user.ID())
	if err := os.Remove(filepath.Join(dir, id+".json")); err != nil {
		slog.Warn("Failed to delete file metadata", "path", filepath.Join(dir, id+".json"), "error", err)
	}
	return os.Remove(filepath.Join(dir, id+".data"))
}

// GetFile returns file content and original name.
func (b *FileBackend) GetFile(user *core.User, id string) ([]byte, string, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	dir := b.uploadDir(user.ID())

	// Read metadata for original filename
	metaRaw, err := os.ReadFile(filepath.Join(dir, id+".json"))
	if err != nil {
		return nil, "", err
	}
	var meta uploadMeta
	if unmarshalErr := json.Unmarshal(metaRaw, &meta); unmarshalErr != nil {
		return nil, "", unmarshalErr
	}

	// Read content
	content, err := os.ReadFile(filepath.Join(dir, id+".data"))
	if err != nil {
		return nil, "", err
	}

	return content, meta.Filename, nil
}

// SearchMessages searches for messages matching the query.
func (b *FileBackend) SearchMessages(user *core.User, query core.MessageQuery) (core.MessageResult, error) {
	b.mu.RLock()
	defer b.mu.RUnlock()

	userDir := b.userDir(user.ID())
	var messages []core.Message

	re, err := regexp.Compile("(?i)" + query.Match)
	if err != nil {
		return core.MessageResult{}, err
	}

	limit := query.Limit
	if limit <= 0 || limit > 200 {
		limit = 60
	}

	// Walk user directory to find all .log files
	err = filepath.WalkDir(userDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(d.Name(), ".log") || d.Name() == "notifications.log" {
			return nil
		}

		// Read log file and filter messages
		msgs, err := b.searchInLogFile(path, re, limit)
		if err == nil {
			messages = append(messages, msgs...)
		}

		if len(messages) >= limit {
			return filepath.SkipAll
		}

		return nil
	})

	if err != nil && !errors.Is(err, filepath.SkipAll) {
		return core.MessageResult{}, err
	}

	// Sort by timestamp
	sort.Slice(messages, func(i, j int) bool {
		return messages[i].Timestamp < messages[j].Timestamp
	})

	// Limit
	if len(messages) > limit {
		messages = messages[len(messages)-limit:]
	}

	return core.MessageResult{
		End:      true, // For search we don't really have pagination yet
		Messages: messages,
	}, nil
}

func (b *FileBackend) searchInLogFile(path string, re *regexp.Regexp, limit int) ([]core.Message, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var messages []core.Message
	scanner := bufio.NewScanner(file)
	lineRE := regexp.MustCompile(`^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+\d+\s+(.*)$`)

	for scanner.Scan() {
		line := scanner.Text()
		matches := lineRE.FindStringSubmatch(line)
		if matches == nil {
			continue
		}

		if !re.MatchString(matches[2]) {
			continue
		}

		ts, err := time.Parse("2006-01-02T15:04:05", matches[1])
		if err != nil {
			continue
		}

		msg := b.parseMessageLine(matches[2])
		msg.Timestamp = ts.Unix()
		messages = append(messages, msg)

		if len(messages) >= limit {
			break
		}
	}

	return messages, scanner.Err()
}

// Ensure FileBackend implements core.Backend.
var _ core.Backend = (*FileBackend)(nil)
