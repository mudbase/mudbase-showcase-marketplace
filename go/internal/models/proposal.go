package models

// ProposalStatus is the workflow state of a proposal.
type ProposalStatus string

const (
	ProposalStatusPending  ProposalStatus = "pending"
	ProposalStatusAccepted ProposalStatus = "accepted"
	ProposalStatusRejected ProposalStatus = "rejected"
)

// ProposalStatusLabel renders a status value for display.
func ProposalStatusLabel(status ProposalStatus) string {
	switch status {
	case ProposalStatusPending:
		return "Pending"
	case ProposalStatusAccepted:
		return "Accepted"
	case ProposalStatusRejected:
		return "Rejected"
	default:
		return "Unknown"
	}
}

// Proposal mirrors the `proposals` Mudbase collection schema.
type Proposal struct {
	ID             string         `json:"_id"`
	CreatedAt      string         `json:"createdAt"`
	UpdatedAt      string         `json:"updatedAt"`
	ListingID      string         `json:"listingId"`
	FreelancerID   string         `json:"freelancerId"`
	FreelancerName string         `json:"freelancerName"`
	CoverLetter    string         `json:"coverLetter"`
	ProposedRate   float64        `json:"proposedRate"`
	Status         ProposalStatus `json:"status"`
}

// IsOwnedBy reports whether userID is this proposal's submitting freelancer - the server-derived
// ownership check every proposal read that's freelancer-scoped must use.
func (p Proposal) IsOwnedBy(userID string) bool {
	return userID != "" && p.FreelancerID == userID
}
