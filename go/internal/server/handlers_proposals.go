package server

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
)

// Field length caps mirror the reference web app's ProposalForm zod schema
// (web/src/components/proposals/ProposalForm.tsx): cover letter at least 20 chars, no upper bound
// in the reference schema - this app still caps it generously to keep documents reasonable.
const (
	coverLetterMinLen = 20
	coverLetterMaxLen = 3000
)

// handleProposalCreate submits a new proposal on the listing named in the URL. Route already
// gated by requireRole(rbac.CanSubmitProposal). freelancerId/freelancerName are taken from the
// signed-in session, never from a posted field - the only user-controlled inputs accepted here
// are coverLetter and proposedRate.
func (a *App) handleProposalCreate(w http.ResponseWriter, r *http.Request) {
	listingID := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	coverLetter := strings.TrimSpace(r.FormValue("coverLetter"))
	if len(coverLetter) < coverLetterMinLen {
		redirectWithError(w, r, "/listings/"+listingID, "Cover letter must be at least 20 characters.")
		return
	}
	if len(coverLetter) > coverLetterMaxLen {
		redirectWithError(w, r, "/listings/"+listingID, "Cover letter is too long.")
		return
	}
	proposedRate, err := strconv.ParseFloat(strings.TrimSpace(r.FormValue("proposedRate")), 64)
	if err != nil || proposedRate <= 0 {
		redirectWithError(w, r, "/listings/"+listingID, "Proposed rate must be greater than 0.")
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	if _, err := a.listings.ByID(r.Context(), token, listingID); err != nil {
		redirectNotFound(w, r, "/", "That listing couldn't be found.", err)
		return
	}

	// One proposal per freelancer per listing - mirrors the reference web app's `ownProposal`
	// check (web/src/app/listings/[id]/page.tsx), enforced here server-side rather than only by
	// hiding the form once one exists client-side.
	existing, err := a.proposals.ByFreelancerAndListing(r.Context(), token, data.UserID(), listingID)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	if existing != nil {
		redirectWithError(w, r, "/listings/"+listingID, "You've already submitted a proposal on this listing.")
		return
	}

	if _, err := a.proposals.Create(r.Context(), token, listingID, data.UserID(), data.DisplayName(), coverLetter, proposedRate); err != nil {
		mutationError(w, r, "/listings/"+listingID, err, "Couldn't submit your proposal. Please try again.")
		return
	}

	redirectWithSuccess(w, r, "/listings/"+listingID, "Proposal submitted.")
}

// resolveOwnedProposal fetches proposalID, then that proposal's own listingId, then that listing,
// and verifies the listing's clientId matches the signed-in session user - the IDOR-safe pattern
// this app follows throughout: authorization for "can I accept/reject this proposal" is derived
// entirely from documents Mudbase itself returns, never from a hidden-form or query field the
// visitor's browser supplied. A request that guesses or reuses another client's proposal id, or
// forges a listingId alongside it, is rejected here before any write is attempted - not silently
// trusted because the form happened to include the "right-looking" field.
func (a *App) resolveOwnedProposal(r *http.Request, proposalID string) (models.Proposal, error, bool) {
	data := sessionFrom(r)
	token := data.AccessToken()

	proposal, err := a.proposals.ByID(r.Context(), token, proposalID)
	if err != nil {
		return models.Proposal{}, err, false
	}
	listing, err := a.listings.ByID(r.Context(), token, proposal.ListingID)
	if err != nil {
		return models.Proposal{}, err, false
	}
	return proposal, nil, listing.IsOwnedBy(data.UserID())
}

// handleProposalAccept accepts a pending proposal. Ownership of the proposal's parent listing is
// re-derived from server-fetched documents (see resolveOwnedProposal) - not from anything the
// request itself claims about who owns what.
func (a *App) handleProposalAccept(w http.ResponseWriter, r *http.Request) {
	a.handleProposalStatusChange(w, r, models.ProposalStatusAccepted, "Proposal accepted.")
}

// handleProposalReject rejects a pending proposal. Same ownership derivation as
// handleProposalAccept.
func (a *App) handleProposalReject(w http.ResponseWriter, r *http.Request) {
	a.handleProposalStatusChange(w, r, models.ProposalStatusRejected, "Proposal rejected.")
}

func (a *App) handleProposalStatusChange(w http.ResponseWriter, r *http.Request, status models.ProposalStatus, successMessage string) {
	proposalID := chi.URLParam(r, "id")

	proposal, err, isOwner := a.resolveOwnedProposal(r, proposalID)
	if err != nil {
		redirectNotFound(w, r, "/", "That proposal couldn't be found.", err)
		return
	}
	if !isOwner {
		redirectWithError(w, r, "/", "Only the client who posted this listing can review its proposals.")
		return
	}
	if proposal.Status != models.ProposalStatusPending {
		redirectWithError(w, r, "/listings/"+proposal.ListingID, "That proposal has already been reviewed.")
		return
	}

	data := sessionFrom(r)
	if _, err := a.proposals.SetStatus(r.Context(), data.AccessToken(), proposalID, status); err != nil {
		mutationError(w, r, "/listings/"+proposal.ListingID, err, "Couldn't update that proposal. Please try again.")
		return
	}

	redirectWithSuccess(w, r, "/listings/"+proposal.ListingID, successMessage)
}

// ── My proposals ─────────────────────────────────────────────────────────────

// ProposalsMineView is the /proposals/mine page's content payload.
type ProposalsMineView struct {
	Base
	Proposals  []MyProposalItemView
	Empty      bool
	Pagination PaginationView
}

// MyProposalItemView is a display-ready proposal row with its listing's title, used on the
// freelancer's own-proposals page.
type MyProposalItemView struct {
	ProposalItemView
	ListingTitle string
}

func (a *App) handleProposalsMine(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	token := data.AccessToken()
	query := r.URL.Query()
	page := int32(1)
	if p, err := strconv.Atoi(query.Get("page")); err == nil && p > 0 {
		page = int32(p)
	}

	result, err := a.proposals.ByFreelancer(r.Context(), token, data.UserID(), page, minePageSize)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	// One batched-by-loop fetch of each referenced listing's title, instead of an N+1 concern
	// mattering at this demo's page size (minePageSize=10).
	titleCache := make(map[string]string, len(result.Data))
	var items []MyProposalItemView
	for _, proposal := range result.Data {
		title, ok := titleCache[proposal.ListingID]
		if !ok {
			if listing, err := a.listings.ByID(r.Context(), token, proposal.ListingID); err == nil {
				title = listing.Title
			} else {
				title = "Listing"
			}
			titleCache[proposal.ListingID] = title
		}
		items = append(items, MyProposalItemView{
			ProposalItemView: newProposalItemView(proposal),
			ListingTitle:     title,
		})
	}

	view := ProposalsMineView{
		Base:       a.baseView(r, "My proposals"),
		Proposals:  items,
		Empty:      len(items) == 0,
		Pagination: buildPagination("/proposals/mine", query, page, result.Total, minePageSize),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "proposals_mine.html", view)
}
