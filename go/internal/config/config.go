// Package config loads and validates every environment variable this app needs at startup.
// Failing fast here means a misconfigured deployment never serves a single request instead of
// panicking deep inside a request handler the first time a particular env var is touched.
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds every environment-derived setting the app needs, resolved once at startup.
type Config struct {
	// MudbaseURL is the Mudbase API base URL (e.g. https://cloud.mudbase.dev).
	MudbaseURL string
	// ProjectID is this app's Mudbase project ID.
	ProjectID string
	// ListingsCollectionID is the Mudbase collection ID backing the `listings` collection.
	ListingsCollectionID string
	// ListingsCollectionSlug is the `listings` collection's slug (distinct from its _id above) -
	// the dedicated GET /api/search/projects/:id/search endpoint's `collections` query param
	// matches on slug, not collection id. See internal/mbase/search.go.
	ListingsCollectionSlug string
	// ProposalsCollectionID is the Mudbase collection ID backing the `proposals` collection.
	ProposalsCollectionID string
	// MessagesCollectionID is the Mudbase collection ID backing the `messages` collection.
	MessagesCollectionID string
	// SessionSecret signs and encrypts the httpOnly session cookie holding the Mudbase JWT.
	SessionSecret string
	// CookieSecure sets the session cookie's Secure flag. Enable in production (HTTPS); leave off
	// for plain-HTTP local development, where a Secure cookie would silently never be sent.
	CookieSecure bool
	// Port is the local HTTP listen port.
	Port string
}

// Load reads and validates every required environment variable, returning a descriptive error
// for the first one that's missing rather than letting the zero value propagate silently.
func Load() (*Config, error) {
	cfg := &Config{
		MudbaseURL:             envOrDefault("MUDBASE_URL", "https://cloud.mudbase.dev"),
		ProjectID:              os.Getenv("MUDBASE_PROJECT_ID"),
		ListingsCollectionID:   os.Getenv("MUDBASE_LISTINGS_COLLECTION_ID"),
		ListingsCollectionSlug: envOrDefault("MUDBASE_LISTINGS_COLLECTION_SLUG", "listings"),
		ProposalsCollectionID:  os.Getenv("MUDBASE_PROPOSALS_COLLECTION_ID"),
		MessagesCollectionID:   os.Getenv("MUDBASE_MESSAGES_COLLECTION_ID"),
		SessionSecret:          os.Getenv("SESSION_SECRET"),
		CookieSecure:           envOrDefault("COOKIE_SECURE", "false") == "true",
		Port:                   envOrDefault("PORT", "8080"),
	}

	required := map[string]string{
		"MUDBASE_PROJECT_ID":              cfg.ProjectID,
		"MUDBASE_LISTINGS_COLLECTION_ID":  cfg.ListingsCollectionID,
		"MUDBASE_PROPOSALS_COLLECTION_ID": cfg.ProposalsCollectionID,
		"MUDBASE_MESSAGES_COLLECTION_ID":  cfg.MessagesCollectionID,
		"SESSION_SECRET":                  cfg.SessionSecret,
	}
	for name, value := range required {
		if value == "" {
			return nil, fmt.Errorf("config: missing required environment variable %s", name)
		}
	}

	if len(cfg.SessionSecret) < 32 {
		return nil, fmt.Errorf("config: SESSION_SECRET must be at least 32 characters, got %d", len(cfg.SessionSecret))
	}

	if _, err := strconv.Atoi(cfg.Port); err != nil {
		return nil, fmt.Errorf("config: PORT must be numeric: %w", err)
	}

	return cfg, nil
}

func envOrDefault(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
