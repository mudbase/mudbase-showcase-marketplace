package server

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/rbac"
)

// messageContentMaxLen caps a single chat message's length - the reference web app's
// MessageThread.tsx enforces no explicit max (only a non-empty check), so this app picks a
// reasonable bound to keep documents sane.
const messageContentMaxLen = 2000

// handleMessageCreate posts a new message on the listing's thread named in the URL. Route already
// gated by requireSignedIn; visibility (client, or the listing's accepted freelancer) is
// re-derived here from server-fetched documents via canMessageListing - never from a hidden
// "listingId"/"role" field the request itself might carry. senderId/senderName are taken from the
// signed-in session, never from a posted field.
func (a *App) handleMessageCreate(w http.ResponseWriter, r *http.Request) {
	listingID := chi.URLParam(r, "id")
	data := sessionFrom(r)
	token := data.AccessToken()

	listing, err := a.listings.ByID(r.Context(), token, listingID)
	if err != nil {
		redirectNotFound(w, r, "/", "That listing couldn't be found.", err)
		return
	}

	isOwningClient := data.IsSignedIn() && data.Role() == rbac.RoleClient && listing.IsOwnedBy(data.UserID())
	isFreelancer := data.IsSignedIn() && data.Role() == rbac.RoleFreelancer

	canMessage, err := a.canMessageListing(r, listing, isOwningClient, isFreelancer)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	if !canMessage {
		redirectWithError(w, r, "/listings/"+listingID, "You don't have access to this listing's messages.")
		return
	}

	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	content := strings.TrimSpace(r.FormValue("content"))
	if content == "" {
		redirectWithError(w, r, "/listings/"+listingID, "Write a message before sending.")
		return
	}
	if len(content) > messageContentMaxLen {
		redirectWithError(w, r, "/listings/"+listingID, "Messages can't be longer than 2000 characters.")
		return
	}

	if _, err := a.messages.Create(r.Context(), token, listingID, data.UserID(), data.DisplayName(), content); err != nil {
		mutationError(w, r, "/listings/"+listingID, err, "Couldn't send that message. Please try again.")
		return
	}

	http.Redirect(w, r, "/listings/"+listingID, http.StatusSeeOther)
}
