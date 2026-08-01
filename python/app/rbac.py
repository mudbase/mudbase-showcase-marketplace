"""Server-side mirror of ../web/plan/build-plan.md's RBAC matrix.

Unlike a client-side SPA, this app's role checks *are* part of the security
boundary that stands between an end user and Mudbase — there is no browser
JS to "just hide a button" here, every write goes through one of these gates
before this app's own request handler ever calls Mudbase. That said,
Mudbase's collection permissions are collection-level, not automatically
document-level scoped (confirmed in the `baas-integration` skill and in
../web/plan/build-plan.md "RBAC matrix"): a client filtering by their own
`clientId`, or a freelancer filtering by their own `freelancerId`, is this
app's own convention, not something the platform enforces server-side. These
functions are this app's defense-in-depth check on top of that, not a
replacement for real document-level authorization.
"""

_KNOWN_ROLES = frozenset({"client", "freelancer"})
_ROLE_LABELS = {"client": "Client", "freelancer": "Freelancer"}


def is_known_role(role: str | None) -> bool:
    return role in _KNOWN_ROLES


def role_label(role: str | None) -> str:
    return _ROLE_LABELS.get(role or "", "Guest")


def can_post_listing(role: str | None) -> bool:
    return role == "client"


def can_edit_listing(role: str | None, *, listing_client_id: str, current_user_id: str | None) -> bool:
    return role == "client" and current_user_id is not None and listing_client_id == current_user_id


def can_submit_proposal(role: str | None) -> bool:
    return role == "freelancer"


def can_manage_proposals(role: str | None, *, listing_client_id: str, current_user_id: str | None) -> bool:
    """Accept/reject proposals on a listing — the owning client only."""
    return role == "client" and current_user_id is not None and listing_client_id == current_user_id


def can_message(
    role: str | None,
    *,
    listing_client_id: str,
    current_user_id: str | None,
    accepted_freelancer_id: str | None,
) -> bool:
    """A listing's message thread is visible to the listing's client and the
    specific freelancer whose proposal on that listing has been accepted —
    see ../web/plan/build-plan.md "Messaging visibility — design decision"."""
    if current_user_id is None:
        return False
    if role == "client" and listing_client_id == current_user_id:
        return True
    return role == "freelancer" and accepted_freelancer_id == current_user_id
