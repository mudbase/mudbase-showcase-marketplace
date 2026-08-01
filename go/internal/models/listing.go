// Package models holds this app's typed views of the three Mudbase collections it reads and
// writes (listings, proposals, messages) - see plan/build-plan.md for the full schema.
package models

// ListingStatus is the workflow state of a listing.
type ListingStatus string

const (
	ListingStatusOpen       ListingStatus = "open"
	ListingStatusInProgress ListingStatus = "in_progress"
	ListingStatusCompleted  ListingStatus = "completed"
)

// ListingStatusLabel renders a status value for display.
func ListingStatusLabel(status ListingStatus) string {
	switch status {
	case ListingStatusOpen:
		return "Open"
	case ListingStatusInProgress:
		return "In progress"
	case ListingStatusCompleted:
		return "Completed"
	default:
		return "Unknown"
	}
}

// IsValidListingStatus reports whether status is one of this app's three known workflow states.
func IsValidListingStatus(status string) bool {
	switch ListingStatus(status) {
	case ListingStatusOpen, ListingStatusInProgress, ListingStatusCompleted:
		return true
	default:
		return false
	}
}

// Listing mirrors the `listings` Mudbase collection schema.
type Listing struct {
	ID          string        `json:"_id"`
	CreatedAt   string        `json:"createdAt"`
	UpdatedAt   string        `json:"updatedAt"`
	Title       string        `json:"title"`
	Description string        `json:"description"`
	Budget      float64       `json:"budget"`
	Category    string        `json:"category"`
	Status      ListingStatus `json:"status"`
	ClientID    string        `json:"clientId"`
	ClientName  string        `json:"clientName"`
}

// IsOwnedBy reports whether userID is this listing's posting client - the server-derived ownership
// check every listing mutation (edit) must use instead of trusting any client-supplied field. See
// internal/server/handlers_listings.go.
func (l Listing) IsOwnedBy(userID string) bool {
	return userID != "" && l.ClientID == userID
}
