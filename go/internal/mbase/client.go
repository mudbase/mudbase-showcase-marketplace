// Package mbase wraps the real Mudbase Go SDK (github.com/mudbase/mudbase-sdk/go) with this app's
// auth, collection-data, and search operations. It intentionally stays thin: every method maps to
// one real SDK call (or, where the vendored SDK's generated response types have a documented gap
// - see auth.go and search.go - one small, clearly-commented re-decode of the real call's raw
// response body). This is a direct sibling of mudbase-showcase-social/go and
// mudbase-showcase-kanban/go's internal/mbase package - same client shape, same 401 -> refresh ->
// retry wiring (refresh.go) - extended with CreateAnonymousSession/Register (this app allows
// guest browsing, like social/ecommerce) and Search (this app is the first sibling port to need
// the dedicated full-text search endpoint).
package mbase

import (
	"context"
	"net/http"
	"time"

	mudbase "github.com/mudbase/mudbase-sdk/go"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/config"
)

// Client bundles the generated SDK client with the project configuration every call needs.
type Client struct {
	SDK        *mudbase.APIClient
	cfg        *config.Config
	httpClient *http.Client
}

// New builds a Client from the app configuration, wiring the SDK to point at the configured
// Mudbase server exactly as documented: NewConfiguration() then override Servers.
func New(cfg *config.Config) *Client {
	sdkCfg := mudbase.NewConfiguration()
	sdkCfg.Servers = mudbase.ServerConfigurations{
		{URL: cfg.MudbaseURL},
	}
	httpClient := &http.Client{Timeout: 15 * time.Second}
	sdkCfg.HTTPClient = httpClient

	return &Client{
		SDK:        mudbase.NewAPIClient(sdkCfg),
		cfg:        cfg,
		httpClient: httpClient,
	}
}

// ProjectID returns the configured Mudbase project ID.
func (c *Client) ProjectID() string {
	return c.cfg.ProjectID
}

// ListingsCollectionSlug returns the `listings` collection's slug, used by the search endpoint's
// `collections` filter (which matches on slug, not collection id).
func (c *Client) ListingsCollectionSlug() string {
	return c.cfg.ListingsCollectionSlug
}

// authedContext attaches a bearer token to ctx the way the generated SDK expects it
// (context.WithValue(ctx, mudbase.ContextAccessToken, token)) - confirmed against
// mudbase-sdk/go/configuration.go and client.go's prepareRequest, which reads exactly this key.
func authedContext(ctx context.Context, token string) context.Context {
	if token == "" {
		return ctx
	}
	return context.WithValue(ctx, mudbase.ContextAccessToken, token)
}
