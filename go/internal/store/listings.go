// Package store implements every domain operation this app needs against the three Mudbase
// collections (listings, proposals, messages), on top of internal/mbase's generic CRUD/search
// helpers. Every mutation here accepts only the fields a handler has already validated and
// (where ownership matters) already verified against a server-fetched document - these methods
// do not themselves re-derive ownership, since they have no notion of "the current request's
// session user" - that check lives in internal/server's handlers, right before calling into this
// package. See internal/models.Listing.IsOwnedBy / models.Proposal.IsOwnedBy.
package store

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
)

// categorySampleLimit bounds the unfiltered sample used to populate the category filter dropdown -
// this SDK's ListData has no `fields` projection param, so this fetches full documents; fine at
// demo scale.
const categorySampleLimit = 100

// ListingService implements every operation the app needs against the `listings` collection.
type ListingService struct {
	client       *mbase.Client
	collectionID string
}

// NewListingService builds a ListingService bound to the given listings collection ID.
func NewListingService(client *mbase.Client, listingsCollectionID string) *ListingService {
	return &ListingService{client: client, collectionID: listingsCollectionID}
}

// BrowseParams bundles the structured (non-keyword) browse filters - category and/or a budget
// range - applied server-side via the collection-data `filter` param.
type BrowseParams struct {
	Category  string
	MinBudget *float64
	MaxBudget *float64
	Page      int32
	Limit     int32
}

// Browse returns a real server-paginated page of listings matching the given structured filters,
// newest first. Used when no search keyword is present - see Search for the keyword branch.
func (s *ListingService) Browse(ctx context.Context, token string, params BrowseParams) (mbase.ListResult[models.Listing], error) {
	filter := map[string]interface{}{}
	if params.Category != "" {
		filter["category"] = params.Category
	}
	if params.MinBudget != nil || params.MaxBudget != nil {
		budgetFilter := map[string]interface{}{}
		if params.MinBudget != nil {
			budgetFilter["$gte"] = *params.MinBudget
		}
		if params.MaxBudget != nil {
			budgetFilter["$lte"] = *params.MaxBudget
		}
		filter["budget"] = budgetFilter
	}

	result, err := mbase.List[models.Listing](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: filter,
		Sort:   "-createdAt",
		Page:   params.Page,
		Limit:  params.Limit,
	})
	if err != nil {
		return mbase.ListResult[models.Listing]{}, fmt.Errorf("store: browsing listings: %w", err)
	}
	return result, nil
}

// Search runs a keyword search over listing title/description via the dedicated full-text search
// endpoint (the collection-data `filter` param cannot do substring search - see
// internal/mbase/search.go), then applies the category/budget filters client-side over the
// returned batch, matching the reference web app's search branch (web/src/app/page.tsx) since the
// search endpoint doesn't accept additional structured filters alongside `q`.
func (s *ListingService) Search(ctx context.Context, token, query string, filters BrowseParams, limit int32) ([]models.Listing, error) {
	results, err := mbase.Search[models.Listing](ctx, s.client, token, mbase.SearchParams{
		Query:       query,
		Collections: s.client.ListingsCollectionSlug(),
		Limit:       limit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: searching listings: %w", err)
	}

	var matched []models.Listing
	for _, collectionResult := range results {
		for _, listing := range collectionResult.Documents {
			if matchesBrowseFilters(listing, filters) {
				matched = append(matched, listing)
			}
		}
	}
	return matched, nil
}

func matchesBrowseFilters(listing models.Listing, filters BrowseParams) bool {
	if filters.Category != "" && listing.Category != filters.Category {
		return false
	}
	if filters.MinBudget != nil && listing.Budget < *filters.MinBudget {
		return false
	}
	if filters.MaxBudget != nil && listing.Budget > *filters.MaxBudget {
		return false
	}
	return true
}

// ByID fetches a single listing by its Mudbase document ID.
func (s *ListingService) ByID(ctx context.Context, token, id string) (models.Listing, error) {
	listing, err := mbase.Get[models.Listing](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.Listing{}, fmt.Errorf("store: fetching listing %s: %w", id, err)
	}
	return listing, nil
}

// ByClient returns clientID's own listings, newest first, real server-paginated.
func (s *ListingService) ByClient(ctx context.Context, token, clientID string, page, limit int32) (mbase.ListResult[models.Listing], error) {
	result, err := mbase.List[models.Listing](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"clientId": clientID},
		Sort:   "-createdAt",
		Page:   page,
		Limit:  limit,
	})
	if err != nil {
		return mbase.ListResult[models.Listing]{}, fmt.Errorf("store: listing listings for client %s: %w", clientID, err)
	}
	return result, nil
}

// Categories returns the distinct, sorted set of non-empty categories present in an unfiltered
// sample of listings - used only to populate the browse page's category dropdown (there is no
// dedicated "distinct values" endpoint on this platform).
func (s *ListingService) Categories(ctx context.Context, token string) ([]string, error) {
	result, err := mbase.List[models.Listing](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Limit: categorySampleLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: sampling listing categories: %w", err)
	}

	seen := make(map[string]struct{})
	var categories []string
	for _, listing := range result.Data {
		category := strings.TrimSpace(listing.Category)
		if category == "" {
			continue
		}
		if _, ok := seen[category]; ok {
			continue
		}
		seen[category] = struct{}{}
		categories = append(categories, category)
	}
	sort.Strings(categories)
	return categories, nil
}

// CreateInput bundles a new listing's user-supplied fields.
type CreateInput struct {
	Title       string
	Description string
	Budget      float64
	Category    string
}

// Create posts a new listing, owned by clientID/clientName - matches the reference web app's
// useCreateDocument(LISTINGS_COLLECTION_ID) call in listings/new/page.tsx. Route already gated by
// requireRole(rbac.CanPostListing) before this is ever called, and independently by Mudbase's own
// collection permissions server-side.
func (s *ListingService) Create(ctx context.Context, token, clientID, clientName string, input CreateInput) (models.Listing, error) {
	body := map[string]interface{}{
		"title":       input.Title,
		"description": input.Description,
		"budget":      input.Budget,
		"status":      string(models.ListingStatusOpen),
		"clientId":    clientID,
		"clientName":  clientName,
	}
	if input.Category != "" {
		body["category"] = input.Category
	}

	created, err := mbase.Create[models.Listing](ctx, s.client, token, s.collectionID, body)
	if err != nil {
		return models.Listing{}, fmt.Errorf("store: creating listing: %w", err)
	}
	return created, nil
}

// UpdateInput bundles a listing edit's user-supplied fields.
type UpdateInput struct {
	Title       string
	Description string
	Budget      float64
	Category    string
	Status      models.ListingStatus
}

// Update edits a listing's title/description/budget/category/status in place. The caller
// (internal/server/handlers_listings.go's handleListingEditSubmit) must have already verified
// listingID's fetched document is owned by the current session user before calling this - it is
// never given a bare ID plus a trusted hidden `clientId` field from the request.
func (s *ListingService) Update(ctx context.Context, token, listingID string, input UpdateInput) (models.Listing, error) {
	body := map[string]interface{}{
		"title":       input.Title,
		"description": input.Description,
		"budget":      input.Budget,
		"status":      string(input.Status),
	}
	if input.Category != "" {
		body["category"] = input.Category
	} else {
		body["category"] = nil
	}

	updated, err := mbase.Update[models.Listing](ctx, s.client, token, s.collectionID, listingID, body)
	if err != nil {
		return models.Listing{}, fmt.Errorf("store: updating listing %s: %w", listingID, err)
	}
	return updated, nil
}
