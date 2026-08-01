package server

import (
	"net/http"
	"net/url"
	"strconv"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/rbac"
)

// Base holds the fields every page's layout needs (header nav, role badge, flash banner). It is
// embedded in every page-specific data struct so templates can read `.IsSignedIn`, `.Flash`, etc.
// directly at the top level via Go's promoted-field rules.
type Base struct {
	Title        string
	IsSignedIn   bool
	DisplayName  string
	Role         string
	RoleLabel    string
	IsClient     bool
	IsFreelancer bool
	FlashError   string
	FlashSuccess string
}

// baseView builds the Base fields shared by every page from the current request's session.
func (a *App) baseView(r *http.Request, title string) Base {
	data := sessionFrom(r)
	role := data.Role()
	return Base{
		Title:        title,
		IsSignedIn:   data.IsSignedIn(),
		DisplayName:  data.DisplayName(),
		Role:         role,
		RoleLabel:    rbac.Label(role),
		IsClient:     role == rbac.RoleClient,
		IsFreelancer: role == rbac.RoleFreelancer,
	}
}

// PaginationView is a display-ready, query-string-preserving prev/next pager.
type PaginationView struct {
	Page       int32
	TotalPages int32
	HasPrev    bool
	HasNext    bool
	PrevURL    string
	NextURL    string
}

// buildPagination computes a PaginationView for basePath, preserving every existing query param
// except `page` (which it overwrites per link).
func buildPagination(basePath string, query url.Values, page int32, total, limit int32) PaginationView {
	totalPages := int32(1)
	if limit > 0 {
		totalPages = (total + limit - 1) / limit
		if totalPages < 1 {
			totalPages = 1
		}
	}
	pv := PaginationView{Page: page, TotalPages: totalPages}

	linkFor := func(p int32) string {
		q := url.Values{}
		for k, v := range query {
			q[k] = v
		}
		q.Set("page", strconv.FormatInt(int64(p), 10))
		return basePath + "?" + q.Encode()
	}

	if page > 1 {
		pv.HasPrev = true
		pv.PrevURL = linkFor(page - 1)
	}
	if page < totalPages {
		pv.HasNext = true
		pv.NextURL = linkFor(page + 1)
	}
	return pv
}

// ListingCardView is a display-ready listing summary, used on the browse/mine listing pages.
type ListingCardView struct {
	models.Listing
	BudgetDisplay string
	StatusLabel   string
	PostedLabel   string
}

func newListingCardView(listing models.Listing) ListingCardView {
	return ListingCardView{
		Listing:       listing,
		BudgetDisplay: formatCurrency(listing.Budget),
		StatusLabel:   models.ListingStatusLabel(listing.Status),
		PostedLabel:   formatRelativeTime(listing.CreatedAt),
	}
}

// ProposalItemView is a display-ready proposal, used on the listing detail page's "proposals
// received" panel and the freelancer's own-proposal-status panel.
type ProposalItemView struct {
	models.Proposal
	RateDisplay string
	PostedLabel string
	StatusLabel string
	CanAct      bool
}

func newProposalItemView(proposal models.Proposal) ProposalItemView {
	return ProposalItemView{
		Proposal:    proposal,
		RateDisplay: formatCurrency(proposal.ProposedRate),
		PostedLabel: formatRelativeTime(proposal.CreatedAt),
		StatusLabel: models.ProposalStatusLabel(proposal.Status),
		CanAct:      proposal.Status == models.ProposalStatusPending,
	}
}

// MessageItemView is a display-ready chat message.
type MessageItemView struct {
	models.Message
	IsOwn     bool
	Initials  string
	SentLabel string
}

func newMessageItemView(message models.Message, currentUserID string) MessageItemView {
	return MessageItemView{
		Message:   message,
		IsOwn:     message.SenderID == currentUserID,
		Initials:  initials(message.SenderName),
		SentLabel: formatRelativeTime(message.CreatedAt),
	}
}
