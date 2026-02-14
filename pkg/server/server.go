// Package server implements the HTTP server for Convos, including API endpoints and SPA frontend.
package server

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"html/template"
	"io/fs"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/convos-chat/convos/pkg/api"
	"github.com/convos-chat/convos/pkg/bot/actions/gitea"
	"github.com/convos-chat/convos/pkg/bot/actions/github"
	"github.com/convos-chat/convos/pkg/config"
	"github.com/convos-chat/convos/pkg/core"
	"github.com/convos-chat/convos/pkg/handler"
	"github.com/convos-chat/convos/pkg/i18n"
	"github.com/convos-chat/convos/pkg/version"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/gorilla/sessions"
	"github.com/gorilla/websocket"
	"gopkg.in/yaml.v3"
)

//go:embed public templates
var embeddedFiles embed.FS

const (
	httpScheme  = "http"
	httpsScheme = "https"
)

var (
	appTemplate           = template.Must(template.New("app").ParseFS(embeddedFiles, "templates/app.html")).Lookup("app.html")
	swTemplate            = template.Must(template.New("sw").ParseFS(embeddedFiles, "templates/sw.js")).Lookup("sw.js")
	manifestTemplate      = template.Must(template.New("manifest").ParseFS(embeddedFiles, "templates/manifest.json")).Lookup("manifest.json")
	browserconfigTemplate = template.Must(template.New("browserconfig").ParseFS(embeddedFiles, "templates/browserconfig.xml")).Lookup("browserconfig.xml")
)

func ContextMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), core.CtxKeyRequest, r)
		ctx = context.WithValue(ctx, core.CtxKeyResponseWriter, w)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *Server) AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := s.Handler.GetUserFromSession(r)
		if user != nil {
			ctx := context.WithValue(r.Context(), core.CtxKeyUser, user)
			r = r.WithContext(ctx)
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) ReverseProxyMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.Config.ReverseProxy == "" {
			next.ServeHTTP(w, r)
			return
		}
		if base := r.Header.Get("X-Request-Base"); base != "" {
			u, err := url.Parse(base)
			if err != nil {
				next.ServeHTTP(w, r)
				return
			}
			s.Core.Settings().SetBaseURL(u)
			// Update secure cookies based on detected scheme
			if cookieStore, ok := s.Store.(*sessions.CookieStore); ok {
				cookieStore.Options.Secure = u.Scheme == httpsScheme
			}
		}
		// Also detect base from X-Forwarded
		scheme := httpsScheme
		if proto := r.Header.Get("X-Forwarded-Proto"); proto == httpsScheme {
			if cookieStore, ok := s.Store.(*sessions.CookieStore); ok {
				cookieStore.Options.Secure = true
				scheme = httpsScheme
			}
		}
		if host := r.Header.Get("X-Forwarded-Host"); host != "" {
			s.Core.Settings().SetBaseURL(&url.URL{
				Host:   host,
				Scheme: scheme,
			})
		}

		next.ServeHTTP(w, r)
	})
}

func (s *Server) RateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Only rate limit login and register
		if r.Method == http.MethodPost && (r.URL.Path == "/api/user/login" || r.URL.Path == "/api/user/register") {
			s.mu.Lock()
			last, ok := s.lastAccess[r.RemoteAddr]
			if ok && time.Since(last) < 1*time.Second {
				s.mu.Unlock()
				http.Error(w, "Too many requests", http.StatusTooManyRequests)
				return
			}
			s.lastAccess[r.RemoteAddr] = time.Now()
			s.mu.Unlock()
		}
		next.ServeHTTP(w, r)
	})
}

func ProviderMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Provider-Name", "ConvosApp")
		next.ServeHTTP(w, r)
	})
}

func (s *Server) RequireAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip for non-API routes or public API routes
		if !strings.HasPrefix(r.URL.Path, "/api") ||
			r.URL.Path == "/api" ||
			r.URL.Path == "/api/user/login" ||
			r.URL.Path == "/api/user/register" ||
			(strings.HasPrefix(r.URL.Path, "/api/files/") && r.Method == "GET") ||
			strings.HasPrefix(r.URL.Path, "/api/i18n/") {
			next.ServeHTTP(w, r)
			return
		}

		user := s.Handler.GetUserFromCtx(r.Context())
		if user == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(handler.ErrResponse("Need to log in first."))
			return
		}

		next.ServeHTTP(w, r)
	})
}

type Server struct {
	Router     *chi.Mux
	Core       *core.Core
	Config     *config.Config
	Store      sessions.Store
	Handler    *handler.Handler
	upgrader   websocket.Upgrader
	publicFS   fs.FS
	assetJS    string // e.g. "convos.58839002.js"
	assetCSS   string // e.g. "style.3c1c3357.css"
	mu         sync.Mutex
	lastAccess map[string]time.Time
}

func New(c *core.Core, cfg *config.Config, authenticator core.Authenticator) *Server {
	// Set log level based on mode
	if cfg.IsDevelopment() {
		slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug})))
		slog.Debug("Running in development mode")
	}

	r := chi.NewRouter()

	s := &Server{
		Router:     r,
		Core:       c,
		Config:     cfg,
		upgrader:   newUpgrader(),
		lastAccess: make(map[string]time.Time),
	}

	s.initPublicFS()
	s.discoverAssets()
	s.initSettingsFromConfig()

	// Resolve session secret: env var > persisted settings > generate new
	sessionSecret := s.resolveSessionSecret()
	store := sessions.NewCookieStore([]byte(sessionSecret))
	store.Options.HttpOnly = true
	if cfg.SecureCookies != nil {
		store.Options.Secure = *cfg.SecureCookies
	} else if u := c.Settings().BaseURL(); u != nil && u.Scheme == "https" {
		store.Options.Secure = true
	}
	store.Options.SameSite = http.SameSiteLaxMode
	store.Options.Path = "/"
	s.Store = store

	// Setup middleware stack
	if cfg.ReverseProxy != "" {
		slog.Debug("Reverse Proxy support enabled")
		r.Use(middleware.RealIP)
		r.Use(s.ReverseProxyMiddleware)
	}
	r.Use(
		stripJSONSuffix,
		ContextMiddleware,
		middleware.Recoverer,
		ProviderMiddleware,
		s.AuthMiddleware,
		s.RequireAuthMiddleware,
		s.RateLimitMiddleware)
	if cfg.IsDevelopment() {
		r.Use(middleware.Logger)
	}

	webhookNets := handler.ParseWebhookNetworks(cfg.WebhookNetworks)
	h := handler.NewHandler(c, authenticator, store, webhookNets)

	h.Bot.RegisterAction(github.NewAction())
	h.Bot.RegisterAction(gitea.NewAction())
	h.Bot.Start()

	i18nCatalog, err := i18n.NewCatalog()
	if err != nil {
		slog.Warn("Failed to load i18n catalog", "error", err)
	} else {
		h.I18n = i18nCatalog
	}

	s.Handler = h

	strictHandler := api.NewStrictHandler(h, []api.StrictMiddlewareFunc{
		func(hf api.StrictHandlerFunc, operationID string) api.StrictHandlerFunc {
			return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
				resp, err := hf(ctx, w, r, request)
				if err != nil && errors.Is(err, handler.ErrUnauthorized) {
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusUnauthorized)
					_ = json.NewEncoder(w).Encode(handler.ErrResponse("Need to log in first."))
					return nil, nil
				}
				if err != nil && errors.Is(err, handler.ErrForbidden) {
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusForbidden)
					_ = json.NewEncoder(w).Encode(handler.ErrResponse("Forbidden"))
					return nil, nil
				}
				if err != nil {
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusInternalServerError)
					if cfg.IsDevelopment() {
						_ = json.NewEncoder(w).Encode(handler.ErrResponse("Internal Server Error: " + err.Error()))
					} else {
						w.Write([]byte(`{"error":"Internal Server Error"}`))
					}
					return nil, nil
				}
				return resp, nil
			}
		},
	})

	// Serve the OpenAPI spec at GET /api (the Svelte client fetches this to discover endpoints)
	r.HandleFunc("/api", s.serveOpenAPISpec)

	// Register API routes
	api.HandlerFromMuxWithBaseURL(strictHandler, r, "/api")

	// WebSocket endpoint
	r.Get("/events", s.eventsHandler)

	// OIDC authentication endpoints
	r.Get("/auth/oidc/login", h.OIDCLoginHandler)
	r.Get("/auth/oidc/callback", h.OIDCCallbackHandler)

	// PWA: service worker, manifest, browserconfig
	r.Get("/sw.js", s.serveServiceWorker)
	r.Get("/sw/info", s.serveServiceWorkerInfo)
	r.Get("/manifest.json", s.serveManifest)
	r.Get("/browserconfig.xml", s.serveBrowserconfig)

	// Static file serving
	fileServer := http.FileServer(http.FS(s.publicFS))
	for _, dir := range []string{"/assets", "/images", "/themes", "/font", "/sounds", "/emojis"} {
		r.Handle(dir+"/*", fileServer)
	}
	// Serve individual static files from public root
	r.Get("/favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		data, err := fs.ReadFile(s.publicFS, "favicon.ico")
		if err != nil {
			http.NotFound(w, r)
			return
		}
		http.ServeContent(w, r, "favicon.ico", time.Time{}, bytes.NewReader(data))
	})

	// SPA routes — all serve the same HTML shell
	spaHandler := s.spaHandler()
	r.Get("/", spaHandler)
	r.Get("/login", spaHandler)
	r.Get("/register", spaHandler)
	r.Get("/search", spaHandler)
	r.Get("/help", spaHandler)
	r.Get("/chat", spaHandler)
	r.Get("/chat/*", spaHandler)
	r.Get("/settings", spaHandler)
	r.Get("/settings/*", spaHandler)
	r.Get("/logout", s.logoutHandler)

	return s
}

func (s *Server) initPublicFS() {
	// 1. Try local pkg/server/public (useful during development)
	if abs, err := filepath.Abs("pkg/server/public"); err == nil {
		if info, err := os.Stat(abs); err == nil && info.IsDir() {
			slog.Debug("Using local filesystem for assets", "path", abs)
			s.publicFS = os.DirFS(abs)
			return
		}
	}

	// 2. Fall back to embedded files
	sub, err := fs.Sub(embeddedFiles, "public")
	if err != nil {
		panic(err)
	}
	slog.Debug("Using embedded filesystem for assets")
	s.publicFS = sub
}

// discoverAssets finds the hashed JS and CSS filenames.
func (s *Server) discoverAssets() {
	entries, err := fs.ReadDir(s.publicFS, "assets")
	if err != nil {
		slog.Warn("assets/ directory not found in publicFS")
		return
	}

	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, "convos.") && strings.HasSuffix(name, ".js") && name != "convos.development.js" {
			s.assetJS = name
		}
		if strings.HasPrefix(name, "style.") && strings.HasSuffix(name, ".css") {
			s.assetCSS = name
		}
	}

	// Fallback to development build if no hashed JS found
	if s.assetJS == "" {
		if _, err := fs.Stat(s.publicFS, "assets/convos.development.js"); err == nil {
			s.assetJS = "convos.development.js"
		}
	}

	slog.Info("Discovered assets", "js", s.assetJS, "css", s.assetCSS)
}

// themeList returns the list of available themes.
func (s *Server) themeList() []themeInfo {
	entries, err := fs.ReadDir(s.publicFS, "themes")
	if err != nil {
		return nil
	}

	themes := make([]themeInfo, 0)
	for _, entry := range entries {
		filename := entry.Name()
		if !strings.HasSuffix(filename, ".css") {
			continue
		}

		name, colorScheme := s.parseThemeCSS("themes/" + filename)
		if name == "" {
			name = strings.TrimSuffix(filename, ".css")
		}
		if colorScheme == "" {
			colorScheme = "normal"
		}

		id := colorScheme + "-" + name
		title := name
		if colorScheme != "normal" {
			title += " (" + colorScheme + ")"
		}

		themes = append(themes, themeInfo{
			ID:    id,
			Title: title,
			URL:   "/themes/" + filename,
		})
	}

	return themes
}

// parseThemeCSS reads the first lines of a CSS file looking for name and color-scheme.
func (s *Server) parseThemeCSS(path string) (string, string) {
	f, err := s.publicFS.Open(path)
	if err != nil {
		return "", ""
	}
	defer f.Close()

	buf := make([]byte, 512)
	n, _ := f.Read(buf)
	header := string(buf[:n])

	var name, colorScheme string
	for _, line := range strings.Split(header, "\n") {
		line = strings.TrimSpace(line)
		if name == "" {
			if idx := strings.Index(strings.ToLower(line), "name:"); idx >= 0 {
				name = strings.TrimSpace(line[idx+5:])
				name = strings.TrimRight(name, " */")
				name = strings.ToLower(name)
			}
		}
		if colorScheme == "" {
			if idx := strings.Index(strings.ToLower(line), "color-scheme:"); idx >= 0 {
				colorScheme = strings.TrimSpace(line[idx+13:])
				colorScheme = strings.TrimRight(colorScheme, " */")
				colorScheme = strings.ToLower(colorScheme)
			}
		}
		if name != "" && colorScheme != "" {
			break
		}
	}
	return name, colorScheme
}

type themeInfo struct {
	ID    string
	Title string
	URL   string
}

type templateData struct {
	AssetCSS         string
	AssetJS          string
	BaseURL          string
	CSRFToken        string
	Contact          string // base64-encoded
	ExistingUser     string // "yes" or "no"
	FirstUser        string // "yes" or "no"
	OpenToPublic     string // "yes" or "no"
	OrganizationName string
	OrganizationURL  string
	OIDCLoginURL     string
	PrimaryTheme     *themeInfo // active theme from cookie, nil if none
	StartApp         string
	Status           int
	Version          string
	Themes           []themeInfo
}

// spaHandler returns an http.HandlerFunc that serves the SPA HTML shell.
func (s *Server) spaHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		users := s.Core.Users()
		hasUsers := len(users) > 0

		// Check if current request has a logged-in user
		existingUser := false
		session, _ := s.Store.Get(r, "convos")
		if email, ok := session.Values["email"].(string); ok && email != "" {
			if s.Core.GetUser(email) != nil {
				existingUser = true
			}
		}

		boolStr := func(v bool) string {
			if v {
				return "yes"
			}
			return "no"
		}

		themes := s.themeList()
		primaryTheme := s.findPrimaryTheme(r, themes)

		csrf := s.csrfToken(r)
		// Save session so the CSRF token is persisted
		err := session.Save(r, w)
		if err != nil {
			slog.Warn("Failed to save session for CSRF token", "error", err)
		}

		data := templateData{
			AssetCSS:         s.assetCSS,
			AssetJS:          s.assetJS,
			BaseURL:          s.baseURL(),
			CSRFToken:        csrf,
			Contact:          base64.StdEncoding.EncodeToString([]byte(s.Config.Contact)),
			ExistingUser:     boolStr(existingUser),
			FirstUser:        boolStr(!hasUsers),
			OpenToPublic:     boolStr(s.Core.Settings().OpenToPublic()),
			OrganizationName: s.Config.OrganizationName,
			OrganizationURL:  s.Config.OrganizationURL,
			OIDCLoginURL:     s.getOIDCLoginURL(),
			PrimaryTheme:     primaryTheme,
			StartApp:         "chat",
			Status:           200,
			Version:          version.Version,
			Themes:           themes,
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := appTemplate.Execute(w, data); err != nil {
			slog.Error("Failed to render template", "error", err)
		}
	}
}

// findPrimaryTheme reads the convos_js cookie to determine the user's active theme.
func (s *Server) findPrimaryTheme(r *http.Request, themes []themeInfo) *themeInfo {
	themeName := "convos"
	colorScheme := "light"

	// Read convos_js cookie (base64-encoded JSON)
	themeName, colorScheme = parseThemeCookie(r, themeName, colorScheme)

	// Try schemes in priority order: requested, normal, light
	schemes := []string{colorScheme, "normal", "light"}
	for _, scheme := range schemes {
		targetID := scheme + "-" + themeName
		for i := range themes {
			if themes[i].ID == targetID {
				return &themes[i]
			}
		}
	}

	// Fallback to first available theme
	if len(themes) > 0 {
		return &themes[0]
	}
	return nil
}

// parseThemeCookie extracts theme and colorScheme from the convos_js cookie.
func parseThemeCookie(r *http.Request, defaultTheme, defaultScheme string) (string, string) {
	cookie, err := r.Cookie("convos_js")
	if err != nil || cookie.Value == "" {
		return defaultTheme, defaultScheme
	}

	decoded, err := base64.StdEncoding.DecodeString(cookie.Value)
	if err != nil {
		return defaultTheme, defaultScheme
	}

	var js map[string]any
	if json.Unmarshal(decoded, &js) != nil {
		return defaultTheme, defaultScheme
	}

	if t, ok := js["theme"].(string); ok && t != "" {
		defaultTheme = t
	}
	if cs, ok := js["colorScheme"].(string); ok && cs != "" {
		defaultScheme = cs
	}
	return defaultTheme, defaultScheme
}

// csrfToken returns the CSRF token for the current session, generating one if needed.
func (s *Server) csrfToken(r *http.Request) string {
	session, _ := s.Store.Get(r, "convos")
	if token, ok := session.Values["csrf_token"].(string); ok && token != "" {
		return token
	}
	// Generate: HMAC-SHA256(random bytes, session secret)
	nonce := make([]byte, 16)
	_, err := rand.Read(nonce)
	if err != nil {
		slog.Warn("Failed to generate CSRF nonce", "error", err)
	}
	mac := hmac.New(sha256.New, []byte(s.Config.SessionSecret))
	mac.Write(nonce)
	token := hex.EncodeToString(mac.Sum(nil))
	session.Values["csrf_token"] = token
	return token
}

// logoutHandler clears the session and redirects to /.
func (s *Server) logoutHandler(w http.ResponseWriter, r *http.Request) {
	session, _ := s.Store.Get(r, "convos")

	// Validate CSRF token on logout (form-based action)
	expected, _ := session.Values["csrf_token"].(string)
	if got := r.URL.Query().Get("csrf"); expected != "" && got != expected {
		http.Error(w, "Invalid CSRF token", http.StatusForbidden)
		return
	}

	session.Values["email"] = nil
	session.Options.MaxAge = -1
	if err := session.Save(r, w); err != nil {
		slog.Warn("Failed to clear session on logout", "error", err)
	}
	http.Redirect(w, r, s.baseURL()+"/login", http.StatusFound)
}

// baseURL returns the base URL for the application (no trailing slash).
func (s *Server) baseURL() string {
	if u := s.Core.Settings().BaseURL(); u != nil {
		str := u.String()
		return strings.TrimRight(str, "/")
	}
	return ""
}

// getOIDCLoginURL returns the OIDC login URL if OIDC is enabled, otherwise empty string.
func (s *Server) getOIDCLoginURL() string {
	if s.Config.Auth.Provider == "oidc" {
		return "/auth/oidc/login"
	}
	return ""
}

// initSettingsFromConfig seeds core settings from config env vars.
func (s *Server) initSettingsFromConfig() {
	settings := s.Core.Settings()
	if s.Config.Contact != "" {
		settings.SetContact(s.Config.Contact)
	}
	if s.Config.OrganizationName != "" {
		settings.SetOrganizationName(s.Config.OrganizationName)
	}
	if s.Config.OrganizationURL != "" {
		settings.SetOrganizationURL(s.Config.OrganizationURL)
	}
	// Default connection for new users
	settings.SetDefaultConnection("irc://irc.libera.chat:6697/%23convos?tls=1")

	// Set base URL from listen address
	if s.Config.Listen != "" {
		if u, err := url.Parse(s.Config.Listen); err == nil {
			settings.SetBaseURL(u)
		}
	}

	// Ensure local_secret exists (used as password substitute in invite HMAC for new users)
	if settings.LocalSecret() == "" {
		settings.SetLocalSecret(generateSecret(20))
		if err := settings.Save(); err != nil {
			slog.Error("Failed to persist generated local secret", "error", err)
		}
	}
}

// resolveSessionSecret determines the session secret to use.
// Priority: CONVOS_SESSION_SECRET env var > persisted session_secrets > generate new.
func (s *Server) resolveSessionSecret() string {
	// 1. Explicit env var takes precedence
	if s.Config.SessionSecret != "" {
		slog.Info("Using session secret from CONVOS_SESSION_SECRET")
		// Ensure it's in settings so handlers can access it for invite token signing
		existing := s.Core.Settings().SessionSecrets()
		if len(existing) == 0 || existing[0] != s.Config.SessionSecret {
			s.Core.Settings().SetSessionSecrets(append([]string{s.Config.SessionSecret}, existing...))
		}
		return s.Config.SessionSecret
	}

	// 2. Check persisted session secrets from settings
	if secrets := s.Core.Settings().SessionSecrets(); len(secrets) > 0 && secrets[0] != "" {
		slog.Info("Using session secret from persisted settings")
		return secrets[0]
	}

	// 3. Generate a new cryptographically secure secret and persist it
	secret := generateSecret(40)
	slog.Info("Generated new session secret (persisting to settings)")
	s.Core.Settings().SetSessionSecrets([]string{secret})
	if err := s.Core.Settings().Save(); err != nil {
		slog.Error("Failed to persist generated session secret", "error", err)
	}
	return secret
}

// generateSecret returns a hex-encoded random string of the given byte length.
func generateSecret(nBytes int) string {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		panic("crypto/rand failed: " + err.Error())
	}
	return hex.EncodeToString(b)
}

// stripJSONSuffix is middleware that strips .json suffix from /api/ URL paths.
func stripJSONSuffix(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") && strings.HasSuffix(r.URL.Path, ".json") {
			r.URL.Path = strings.TrimSuffix(r.URL.Path, ".json")
		}
		if strings.HasPrefix(r.URL.RawPath, "/api/") && strings.HasSuffix(r.URL.RawPath, ".json") {
			r.URL.RawPath = strings.TrimSuffix(r.URL.RawPath, ".json")
		}
		next.ServeHTTP(w, r)
	})
}

// serveOpenAPISpec serves the Swagger 2.0 spec as JSON at /api.
func (s *Server) serveOpenAPISpec(w http.ResponseWriter, r *http.Request) {
	data, err := fs.ReadFile(s.publicFS, "convos-api.yaml")
	if err != nil {
		http.Error(w, "OpenAPI spec not found", http.StatusNotFound)
		return
	}

	// Parse YAML and serve as JSON with the correct host
	var spec map[string]any
	if err := yaml.Unmarshal(data, &spec); err != nil {
		http.Error(w, "Failed to parse spec", http.StatusInternalServerError)
		return
	}

	// Set host to match the actual server
	spec["host"] = r.Host

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(spec)
}

// serveServiceWorker serves the service worker script with caching strategies.
func (s *Server) serveServiceWorker(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/javascript")
	w.Header().Set("Cache-Control", "no-cache")

	basePath := "/"
	if u := s.Core.Settings().BaseURL(); u != nil && u.Path != "" {
		basePath = u.Path
		if !strings.HasSuffix(basePath, "/") {
			basePath += "/"
		}
	}

	cacheFirst := "cache_first"
	if s.Config.IsDevelopment() {
		cacheFirst = "network_first"
	}

	data := map[string]string{
		"Mode":       s.Config.Mode,
		"Version":    version.Version,
		"BasePath":   basePath,
		"CacheFirst": cacheFirst,
	}

	if err := swTemplate.Execute(w, data); err != nil {
		slog.Error("Failed to render service worker template", "error", err)
	}
}

// serveManifest serves the PWA web app manifest.
func (s *Server) serveManifest(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/manifest+json")
	data := map[string]string{"BaseURL": s.baseURL()}
	if err := manifestTemplate.Execute(w, data); err != nil {
		slog.Error("Failed to render manifest template", "error", err)
	}
}

// serveBrowserconfig serves the Microsoft browser configuration XML.
func (s *Server) serveBrowserconfig(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/xml")
	if err := browserconfigTemplate.Execute(w, nil); err != nil {
		slog.Error("Failed to render browserconfig template", "error", err)
	}
}

// serveServiceWorkerInfo returns service worker metadata.
func (s *Server) serveServiceWorkerInfo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"mode":    s.Config.Mode,
		"version": version.Version,
	})
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.Router.ServeHTTP(w, r)
}
