// Package rbac defines this app's two role slugs and the operations each one may perform. This is
// a server-side mirror of the reference web app's RBAC matrix (web/plan/build-plan.md), used two
// ways in this app: (1) internal/server/middleware.go's requireRole gates every write route
// before a handler ever runs (the "server-side enforcement" the task requires, not just hidden
// template controls), and (2) the page templates read the same Can*/Is* flags to decide what to
// render.
//
// Neither of those is the real security boundary for role-level checks - Mudbase's own collection
// permissions are (see mbase.IsForbidden). And neither of those is the boundary for
// *document*-level ownership at all (client A editing client B's listing, or a non-owner
// accepting someone else's proposal) - that check exists nowhere in Mudbase's collection-level
// permission system, so internal/server's handlers must derive it themselves from server-fetched
// documents, never from a client-supplied field. See models.Listing.IsOwnedBy /
// models.Proposal.IsOwnedBy and every handler that calls them.
package rbac

// Role slugs this project's Multi-Role auth is configured with.
const (
	RoleClient     = "client"
	RoleFreelancer = "freelancer"
)

// CanPostListing reports whether role may create/edit a listing.
func CanPostListing(role string) bool {
	return role == RoleClient
}

// CanSubmitProposal reports whether role may submit a proposal on a listing.
func CanSubmitProposal(role string) bool {
	return role == RoleFreelancer
}

// Label renders a role slug for display, "Guest" for an anonymous/empty role.
func Label(role string) string {
	switch role {
	case RoleClient:
		return "Client"
	case RoleFreelancer:
		return "Freelancer"
	default:
		return "Guest"
	}
}

// IsValid reports whether role is one of this app's two known slugs.
func IsValid(role string) bool {
	return role == RoleClient || role == RoleFreelancer
}
