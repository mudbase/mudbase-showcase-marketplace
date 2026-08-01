package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
)

// proposalsPerListingLimit bounds how many proposals a single listing detail page renders.
const proposalsPerListingLimit = 200

// ProposalService implements every operation the app needs against the `proposals` collection.
type ProposalService struct {
	client       *mbase.Client
	collectionID string
}

// NewProposalService builds a ProposalService bound to the given proposals collection ID.
func NewProposalService(client *mbase.Client, proposalsCollectionID string) *ProposalService {
	return &ProposalService{client: client, collectionID: proposalsCollectionID}
}

// ForListing returns every proposal submitted against listingID, newest first - used by the
// owning client's "proposals received" panel.
func (s *ProposalService) ForListing(ctx context.Context, token, listingID string) ([]models.Proposal, error) {
	result, err := mbase.List[models.Proposal](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"listingId": listingID},
		Sort:   "-createdAt",
		Limit:  proposalsPerListingLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing proposals for listing %s: %w", listingID, err)
	}
	return result.Data, nil
}

// ByFreelancerAndListing returns freelancerID's own proposal on listingID, if any - used to decide
// whether the listing detail page shows the submission form or the freelancer's existing status
// (matches the reference web app's `ownProposal` query in listings/[id]/page.tsx).
func (s *ProposalService) ByFreelancerAndListing(ctx context.Context, token, freelancerID, listingID string) (*models.Proposal, error) {
	result, err := mbase.List[models.Proposal](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"listingId": listingID, "freelancerId": freelancerID},
		Limit:  1,
	})
	if err != nil {
		return nil, fmt.Errorf("store: fetching own proposal for listing %s: %w", listingID, err)
	}
	if len(result.Data) == 0 {
		return nil, nil
	}
	return &result.Data[0], nil
}

// AcceptedForListing returns the single accepted proposal on listingID, if any - this decides who
// besides the client can see and use the listing's message thread (see
// plan/build-plan.md "Messaging visibility"). At most one proposal is ever accepted per listing in
// this app's flow (the client accepts exactly one), but this defensively takes the first if
// Mudbase ever returned more than one.
func (s *ProposalService) AcceptedForListing(ctx context.Context, token, listingID string) (*models.Proposal, error) {
	result, err := mbase.List[models.Proposal](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"listingId": listingID, "status": string(models.ProposalStatusAccepted)},
		Limit:  1,
	})
	if err != nil {
		return nil, fmt.Errorf("store: fetching accepted proposal for listing %s: %w", listingID, err)
	}
	if len(result.Data) == 0 {
		return nil, nil
	}
	return &result.Data[0], nil
}

// ByFreelancer returns freelancerID's own proposals across every listing, newest first, real
// server-paginated - backs the /proposals/mine page.
func (s *ProposalService) ByFreelancer(ctx context.Context, token, freelancerID string, page, limit int32) (mbase.ListResult[models.Proposal], error) {
	result, err := mbase.List[models.Proposal](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"freelancerId": freelancerID},
		Sort:   "-createdAt",
		Page:   page,
		Limit:  limit,
	})
	if err != nil {
		return mbase.ListResult[models.Proposal]{}, fmt.Errorf("store: listing proposals for freelancer %s: %w", freelancerID, err)
	}
	return result, nil
}

// ByID fetches a single proposal by its Mudbase document ID.
func (s *ProposalService) ByID(ctx context.Context, token, id string) (models.Proposal, error) {
	proposal, err := mbase.Get[models.Proposal](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.Proposal{}, fmt.Errorf("store: fetching proposal %s: %w", id, err)
	}
	return proposal, nil
}

// Create submits a new proposal, authored by freelancerID/freelancerName, on listingID. Route
// already gated by requireRole(rbac.CanSubmitProposal) before this is ever called, and
// independently by Mudbase's own collection permissions server-side.
func (s *ProposalService) Create(ctx context.Context, token, listingID, freelancerID, freelancerName, coverLetter string, proposedRate float64) (models.Proposal, error) {
	created, err := mbase.Create[models.Proposal](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"listingId":      listingID,
		"freelancerId":   freelancerID,
		"freelancerName": freelancerName,
		"coverLetter":    coverLetter,
		"proposedRate":   proposedRate,
		"status":         string(models.ProposalStatusPending),
	})
	if err != nil {
		return models.Proposal{}, fmt.Errorf("store: creating proposal on listing %s: %w", listingID, err)
	}
	return created, nil
}

// SetStatus accepts or rejects a proposal. The caller (internal/server/handlers_proposals.go's
// handleProposalAccept/handleProposalReject) must have already fetched proposalID's document,
// fetched *that document's own* listingId, and verified the listing's clientId matches the
// current session user - never trust a hidden-form/query field for who owns the parent listing.
func (s *ProposalService) SetStatus(ctx context.Context, token, proposalID string, status models.ProposalStatus) (models.Proposal, error) {
	updated, err := mbase.Update[models.Proposal](ctx, s.client, token, s.collectionID, proposalID, map[string]interface{}{
		"status": string(status),
	})
	if err != nil {
		return models.Proposal{}, fmt.Errorf("store: updating proposal %s status: %w", proposalID, err)
	}
	return updated, nil
}
