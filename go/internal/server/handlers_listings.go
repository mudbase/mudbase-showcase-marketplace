package server

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/rbac"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/store"
)

// Field length caps mirror the reference web app's ListingForm zod schema
// (web/src/components/listings/ListingForm.tsx): title 3-120 chars, category up to 60. Description
// has no upper bound in the reference schema; this app still caps it generously to keep documents
// reasonable.
const (
	listingTitleMinLen       = 3
	listingTitleMaxLen       = 120
	listingDescriptionMinLen = 20
	listingDescriptionMaxLen = 5000
	listingCategoryMaxLen    = 60
)

const homePageSize = 12
const minePageSize = 10
const searchResultLimit = 50

// ── Browse (home) ────────────────────────────────────────────────────────────

// HomeView is the `/` page's content payload.
type HomeView struct {
	Base
	Search     string
	Category   string
	MinBudget  string
	MaxBudget  string
	Categories []string
	Listings   []ListingCardView
	Empty      bool
	Pagination PaginationView
}

// buildBrowseParams builds a store.BrowseParams from raw query-string values.
func buildBrowseParams(category, minBudgetRaw, maxBudgetRaw string, page, limit int32) store.BrowseParams {
	return store.BrowseParams{
		Category:  category,
		MinBudget: parseBudgetParam(minBudgetRaw),
		MaxBudget: parseBudgetParam(maxBudgetRaw),
		Page:      page,
		Limit:     limit,
	}
}

func parseBudgetParam(raw string) *float64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil || v < 0 {
		return nil
	}
	return &v
}

func (a *App) handleHome(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	token := data.AccessToken()
	query := r.URL.Query()

	search := strings.TrimSpace(query.Get("q"))
	category := strings.TrimSpace(query.Get("category"))
	minBudgetRaw := strings.TrimSpace(query.Get("minBudget"))
	maxBudgetRaw := strings.TrimSpace(query.Get("maxBudget"))
	page := int32(1)
	if p, err := strconv.Atoi(query.Get("page")); err == nil && p > 0 {
		page = int32(p)
	}

	filters := buildBrowseParams(category, minBudgetRaw, maxBudgetRaw, page, homePageSize)

	var listingViews []ListingCardView
	var pagination PaginationView

	if search != "" {
		matched, err := a.listings.Search(r.Context(), token, search, filters, searchResultLimit)
		if err != nil {
			a.serverError(w, r, err)
			return
		}
		total := int32(len(matched))
		start := (page - 1) * homePageSize
		end := start + homePageSize
		if start > total {
			start = total
		}
		if end > total {
			end = total
		}
		for _, listing := range matched[start:end] {
			listingViews = append(listingViews, newListingCardView(listing))
		}
		pagination = buildPagination("/", query, page, total, homePageSize)
	} else {
		result, err := a.listings.Browse(r.Context(), token, filters)
		if err != nil {
			a.serverError(w, r, err)
			return
		}
		for _, listing := range result.Data {
			listingViews = append(listingViews, newListingCardView(listing))
		}
		pagination = buildPagination("/", query, page, result.Total, homePageSize)
	}

	categories, err := a.listings.Categories(r.Context(), token)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := HomeView{
		Base:       a.baseView(r, "Browse listings"),
		Search:     search,
		Category:   category,
		MinBudget:  minBudgetRaw,
		MaxBudget:  maxBudgetRaw,
		Categories: categories,
		Listings:   listingViews,
		Empty:      len(listingViews) == 0,
		Pagination: pagination,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "home.html", view)
}

// ── Listing detail ───────────────────────────────────────────────────────────

// ListingDetailBodyView is the poll-refreshed part of the listing detail page (proposals list +
// message thread), shared by the full page and its fragment - this app's stand-in for the
// reference web app's TanStack Query polling, since there is no client-side JS framework here.
type ListingDetailBodyView struct {
	IsOwningClient     bool
	ViewerIsFreelancer bool
	OwnProposal        *ProposalItemView
	CanSubmitProposal  bool
	Proposals          []ProposalItemView
	ProposalsEmpty     bool
	CanMessage         bool
	Messages           []MessageItemView
	MessagesEmpty      bool
}

// canMessageListing reports whether the current session user may read/write listing's message
// thread: the listing's own client, or the specific freelancer whose proposal on it has been
// accepted (see plan/build-plan.md "Messaging visibility") - never any other applicant. This is
// derived entirely from server-fetched documents (the listing's own clientId, and a fresh query
// for the accepted proposal's freelancerId), never from a hidden-form/query field - the same
// IDOR-safe pattern as resolveOwnedProposal in handlers_proposals.go. Shared by the listing
// detail page/fragment (read) and handleMessageCreate (write) so the two can never drift out of
// sync with each other.
func (a *App) canMessageListing(r *http.Request, listing models.Listing, isOwningClient, isFreelancer bool) (bool, error) {
	if isOwningClient {
		return true, nil
	}
	if !isFreelancer {
		return false, nil
	}
	data := sessionFrom(r)
	accepted, err := a.proposals.AcceptedForListing(r.Context(), data.AccessToken(), listing.ID)
	if err != nil {
		return false, err
	}
	return accepted != nil && accepted.IsOwnedBy(data.UserID()), nil
}

func (a *App) listingDetailBody(r *http.Request, listing models.Listing) (ListingDetailBodyView, error) {
	data := sessionFrom(r)
	token := data.AccessToken()
	userID := data.UserID()
	role := data.Role()
	isSignedIn := data.IsSignedIn()

	isOwningClient := isSignedIn && role == rbac.RoleClient && listing.IsOwnedBy(userID)
	isFreelancer := isSignedIn && role == rbac.RoleFreelancer

	body := ListingDetailBodyView{
		IsOwningClient:     isOwningClient,
		ViewerIsFreelancer: isFreelancer,
	}

	if isFreelancer {
		own, err := a.proposals.ByFreelancerAndListing(r.Context(), token, userID, listing.ID)
		if err != nil {
			return ListingDetailBodyView{}, err
		}
		if own != nil {
			view := newProposalItemView(*own)
			body.OwnProposal = &view
		} else {
			body.CanSubmitProposal = true
		}
	}

	if isOwningClient {
		list, err := a.proposals.ForListing(r.Context(), token, listing.ID)
		if err != nil {
			return ListingDetailBodyView{}, err
		}
		for _, p := range list {
			body.Proposals = append(body.Proposals, newProposalItemView(p))
		}
		body.ProposalsEmpty = len(body.Proposals) == 0
	}

	canMessage, err := a.canMessageListing(r, listing, isOwningClient, isFreelancer)
	if err != nil {
		return ListingDetailBodyView{}, err
	}
	body.CanMessage = canMessage

	if canMessage {
		msgs, err := a.messages.ForListing(r.Context(), token, listing.ID)
		if err != nil {
			return ListingDetailBodyView{}, err
		}
		for _, m := range msgs {
			body.Messages = append(body.Messages, newMessageItemView(m, userID))
		}
		body.MessagesEmpty = len(body.Messages) == 0
	}

	return body, nil
}

// ListingDetailView is the /listings/{id} page's content payload.
type ListingDetailView struct {
	Base
	Listing       models.Listing
	BudgetDisplay string
	StatusLabel   string
	PostedLabel   string
	ListingDetailBodyView
}

func (a *App) handleListingDetail(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	listing, err := a.listings.ByID(r.Context(), token, id)
	if err != nil {
		redirectNotFound(w, r, "/", "That listing couldn't be found.", err)
		return
	}

	body, err := a.listingDetailBody(r, listing)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := ListingDetailView{
		Base:                  a.baseView(r, listing.Title),
		Listing:               listing,
		BudgetDisplay:         formatCurrency(listing.Budget),
		StatusLabel:           models.ListingStatusLabel(listing.Status),
		PostedLabel:           formatRelativeTime(listing.CreatedAt),
		ListingDetailBodyView: body,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "listing_detail.html", view)
}

// handleListingDetailFragment renders just the proposals panel + message thread (no layout, no
// listing header), polled every few seconds by a small inline script on the listing detail page.
func (a *App) handleListingDetailFragment(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	listing, err := a.listings.ByID(r.Context(), token, id)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	body, err := a.listingDetailBody(r, listing)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	a.renderFragment(w, r, http.StatusOK, "listing_detail_fragment.html", body)
}

// ── Post / edit listing ──────────────────────────────────────────────────────

// ListingFormView is the /listings/new and /listings/{id}/edit pages' content payload.
//
// The listing's own title field is named ListingTitle, not Title - Base already declares a Title
// field (the <title> tag / page heading text, e.g. "Post a listing") and a same-named direct
// field here would shadow it in every template lookup (Go's field-selector resolution always
// prefers the shallower field on ambiguity-free shadowing, so `.Title` would silently render the
// listing's title instead of the intended page title - a real bug this app's own template.go
// startup parse can't catch, since both are valid string fields).
type ListingFormView struct {
	Base
	Mode         string // "create" | "edit"
	ID           string
	ListingTitle string
	Description  string
	Category     string
	Budget       string
	Status       models.ListingStatus
	Statuses     []listingStatusOption
}

type listingStatusOption struct {
	Value    models.ListingStatus
	Label    string
	Selected bool
}

func listingStatusOptions(current models.ListingStatus) []listingStatusOption {
	statuses := []models.ListingStatus{models.ListingStatusOpen, models.ListingStatusInProgress, models.ListingStatusCompleted}
	options := make([]listingStatusOption, 0, len(statuses))
	for _, s := range statuses {
		options = append(options, listingStatusOption{Value: s, Label: models.ListingStatusLabel(s), Selected: s == current})
	}
	return options
}

func (a *App) handleListingNewShow(w http.ResponseWriter, r *http.Request) {
	view := ListingFormView{
		Base: a.baseView(r, "Post a listing"),
		Mode: "create",
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "listing_new.html", view)
}

func validateListingForm(title, description, budgetRaw, category string) (float64, string) {
	if len(title) < listingTitleMinLen {
		return 0, "Title must be at least 3 characters."
	}
	if len(title) > listingTitleMaxLen {
		return 0, "Title is too long."
	}
	if len(description) < listingDescriptionMinLen {
		return 0, "Description must be at least 20 characters."
	}
	if len(description) > listingDescriptionMaxLen {
		return 0, "Description is too long."
	}
	if len(category) > listingCategoryMaxLen {
		return 0, "Category is too long."
	}
	budget, err := strconv.ParseFloat(strings.TrimSpace(budgetRaw), 64)
	if err != nil || budget <= 0 {
		return 0, "Budget must be greater than 0."
	}
	return budget, ""
}

// handleListingCreate posts a new listing, owned by the signed-in client. Route already gated by
// requireRole(rbac.CanPostListing).
func (a *App) handleListingCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	title := strings.TrimSpace(r.FormValue("title"))
	description := strings.TrimSpace(r.FormValue("description"))
	category := strings.TrimSpace(r.FormValue("category"))
	budget, message := validateListingForm(title, description, r.FormValue("budget"), category)
	if message != "" {
		redirectWithError(w, r, "/listings/new", message)
		return
	}

	data := sessionFrom(r)
	listing, err := a.listings.Create(r.Context(), data.AccessToken(), data.UserID(), data.DisplayName(), store.CreateInput{
		Title:       title,
		Description: description,
		Budget:      budget,
		Category:    category,
	})
	if err != nil {
		mutationError(w, r, "/listings/new", err, "Couldn't post that listing. Please try again.")
		return
	}

	http.Redirect(w, r, "/listings/"+listing.ID, http.StatusSeeOther)
}

// handleListingEditShow renders the edit form. Ownership is verified here from the server-fetched
// listing document, not from any client-supplied field - a non-owning visitor sees a plain denial
// message instead of the form (mirrors the reference web app's isOwner gate in
// listings/[id]/edit/page.tsx, but enforced server-side here rather than only in client JS).
func (a *App) handleListingEditShow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)

	listing, err := a.listings.ByID(r.Context(), data.AccessToken(), id)
	if err != nil {
		redirectNotFound(w, r, "/", "That listing couldn't be found.", err)
		return
	}
	if !listing.IsOwnedBy(data.UserID()) {
		redirectWithError(w, r, "/listings/"+id, "Only the client who posted this listing can edit it.")
		return
	}

	view := ListingFormView{
		Base:         a.baseView(r, "Edit listing"),
		Mode:         "edit",
		ID:           listing.ID,
		ListingTitle: listing.Title,
		Description:  listing.Description,
		Category:     listing.Category,
		Budget:       strconv.FormatFloat(listing.Budget, 'f', -1, 64),
		Status:       listing.Status,
		Statuses:     listingStatusOptions(listing.Status),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "listing_edit.html", view)
}

// handleListingEditSubmit saves an edit. Ownership is re-verified here from a freshly server-
// fetched listing document keyed only by the URL's {id} - the IDOR-safe pattern this app follows
// throughout: never trust a hidden-form/query value (a `clientId` field, say) for who is allowed
// to mutate a record. Re-deriving ownership from the document Mudbase itself just returned is what
// makes a forged form submission (someone else's listing id typed into this same route) fail here
// even before Mudbase's own collection permissions get a chance to reject it.
func (a *App) handleListingEditSubmit(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	listing, err := a.listings.ByID(r.Context(), token, id)
	if err != nil {
		redirectNotFound(w, r, "/", "That listing couldn't be found.", err)
		return
	}
	if !listing.IsOwnedBy(data.UserID()) {
		redirectWithError(w, r, "/listings/"+id, "Only the client who posted this listing can edit it.")
		return
	}

	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	title := strings.TrimSpace(r.FormValue("title"))
	description := strings.TrimSpace(r.FormValue("description"))
	category := strings.TrimSpace(r.FormValue("category"))
	statusRaw := r.FormValue("status")
	budget, message := validateListingForm(title, description, r.FormValue("budget"), category)
	if message != "" {
		redirectWithError(w, r, "/listings/"+id+"/edit", message)
		return
	}
	if !models.IsValidListingStatus(statusRaw) {
		redirectWithError(w, r, "/listings/"+id+"/edit", "Choose a valid status.")
		return
	}

	if _, err := a.listings.Update(r.Context(), token, id, store.UpdateInput{
		Title:       title,
		Description: description,
		Budget:      budget,
		Category:    category,
		Status:      models.ListingStatus(statusRaw),
	}); err != nil {
		mutationError(w, r, "/listings/"+id+"/edit", err, "Couldn't save those changes. Please try again.")
		return
	}

	redirectWithSuccess(w, r, "/listings/"+id, "Listing updated.")
}

// ── My listings ──────────────────────────────────────────────────────────────

// ListingsMineView is the /listings/mine page's content payload.
type ListingsMineView struct {
	Base
	Listings   []MyListingItemView
	Empty      bool
	Pagination PaginationView
}

// MyListingItemView is a display-ready listing row with a proposal count, used on the client's
// own-listings page.
type MyListingItemView struct {
	ListingCardView
	ProposalCount int
}

func (a *App) handleListingsMine(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	token := data.AccessToken()
	query := r.URL.Query()
	page := int32(1)
	if p, err := strconv.Atoi(query.Get("page")); err == nil && p > 0 {
		page = int32(p)
	}

	result, err := a.listings.ByClient(r.Context(), token, data.UserID(), page, minePageSize)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	var items []MyListingItemView
	for _, listing := range result.Data {
		count := 0
		proposalsForListing, err := a.proposals.ForListing(r.Context(), token, listing.ID)
		if err == nil {
			count = len(proposalsForListing)
		}
		items = append(items, MyListingItemView{ListingCardView: newListingCardView(listing), ProposalCount: count})
	}

	view := ListingsMineView{
		Base:       a.baseView(r, "My listings"),
		Listings:   items,
		Empty:      len(items) == 0,
		Pagination: buildPagination("/listings/mine", query, page, result.Total, minePageSize),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "listings_mine.html", view)
}
