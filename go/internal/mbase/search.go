package mbase

import (
	"context"
	"encoding/json"
	"fmt"
)

// Known SDK gap (new to this port - no sibling showcase needed full-text search before this one):
// the vendored mudbase-sdk/go's generated SearchAPI models (SearchResponse -> SearchResponseData
// -> []SearchResult -> SearchResultItem) declare only `_id`/`score` on the matched item, discarding
// every actual document field (title, description, budget, ...) the live endpoint returns. That
// shape also doesn't match the reference web app's own confirmed-live usage in
// web/src/lib/mudbase.ts's search()/SearchResponse<T>, which is a flat
// `{ results: [{ collection, results: T[], pagination }], query, totalResults, executionTime }` -
// one entry in the outer `results` array per requested collection, each carrying the *full*
// matched documents in its own `results` field. Per this package's established pattern for this
// exact class of gap (see auth.go's decodeAuthBody workaround, documented in every sibling port),
// this file still executes through the real generated SDK method (for request construction,
// query-param encoding, auth header wiring, and error handling), then re-decodes the raw response
// body against the shape confirmed by the reference web app instead of the incomplete generated
// model.
type searchWireCollection struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

type searchWirePagination struct {
	Page       int32 `json:"page"`
	Limit      int32 `json:"limit"`
	Total      int32 `json:"total"`
	TotalPages int32 `json:"totalPages"`
}

type searchWireCollectionResult struct {
	Collection searchWireCollection `json:"collection"`
	Results    []json.RawMessage    `json:"results"`
	Pagination searchWirePagination `json:"pagination"`
}

type searchWireResponse struct {
	Results       []searchWireCollectionResult `json:"results"`
	Query         string                       `json:"query"`
	TotalResults  int32                        `json:"totalResults"`
	ExecutionTime int32                        `json:"executionTime"`
}

// SearchResult is one collection's worth of full-text search matches, decoded into T.
type SearchResult[T any] struct {
	Collection string
	Documents  []T
	Pagination searchWirePagination
}

// SearchParams mirrors the query options the real full-text search endpoint accepts.
type SearchParams struct {
	Query       string
	Collections string // comma-separated collection slugs
	Limit       int32
}

// Search runs a server-side keyword search across collectionSlug's indexed string fields
// (title/description/name/content/email). This is the real search surface for this app's listings
// browse/search feature - the collection-data `filter` param cannot do substring search: `$regex`
// and `$text`'s `$search` are both hard-blocked on the deployed query sanitizer's dangerous-
// operator blocklist (confirmed live against this project, see plan/build-plan.md). This endpoint
// builds its own regex server-side from `q`, not from client input passed through that sanitizer,
// so it isn't subject to the block. See List's doc comment (data.go) for the 401-refresh behavior
// shared by every function in this package.
func Search[T any](ctx context.Context, c *Client, token string, params SearchParams) ([]SearchResult[T], error) {
	var wire searchWireResponse
	err := callWithRefresh(ctx, token, func(tok string) error {
		req := c.SDK.SearchAPI.SearchData(authedContext(ctx, tok), c.cfg.ProjectID).Q(params.Query)
		if params.Collections != "" {
			req = req.Collections(params.Collections)
		}
		if params.Limit > 0 {
			req = req.Limit(params.Limit)
		}

		_, httpResp, execErr := req.Execute()
		if execErr != nil {
			return execErr
		}
		body, readErr := readPreservedBody(httpResp)
		if readErr != nil {
			return readErr
		}
		if err := json.Unmarshal(body, &wire); err != nil {
			return fmt.Errorf("mbase: decoding search response body: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, wrapAPIError("mbase: searching", err)
	}

	out := make([]SearchResult[T], 0, len(wire.Results))
	for _, collectionResult := range wire.Results {
		docs := make([]T, 0, len(collectionResult.Results))
		for _, raw := range collectionResult.Results {
			decoded, decodeErr := decodeInto[T](json.RawMessage(raw))
			if decodeErr != nil {
				return nil, fmt.Errorf("mbase: decoding search result document: %w", decodeErr)
			}
			docs = append(docs, decoded)
		}
		out = append(out, SearchResult[T]{
			Collection: collectionResult.Collection.Slug,
			Documents:  docs,
			Pagination: collectionResult.Pagination,
		})
	}
	return out, nil
}
