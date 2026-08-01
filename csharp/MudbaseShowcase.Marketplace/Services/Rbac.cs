namespace MudbaseShowcase.Marketplace.Services;

/// <summary>
/// Client-/server-side mirror of the RBAC matrix Mudbase's own collection permissions already
/// enforce server-side on the real project (see plan/build-plan.md). Used both to hide/disable
/// controls a role cannot use in the Razor views, and as a second, server-side check inside every
/// mutating Razor Page handler before ever calling Mudbase - it is NOT the real security boundary
/// by itself. Critically, every mutating handler ALSO re-derives ownership (proposal.freelancerId
/// == current user, listing.clientId == current user) from the document just fetched from
/// Mudbase, never from a hidden form field - see Pages/Listings/Detail.cshtml.cs's
/// OnPostAcceptAsync/OnPostRejectAsync and Pages/Listings/Edit.cshtml.cs's OnPostAsync for why:
/// the sibling mudbase-showcase-events/csharp port's csharp-reviewer pass found a real IDOR there
/// (a booking-cancellation handler trusted a hidden eventId/capacity form field with no ownership
/// check), and that mistake is deliberately not repeated here.
/// </summary>
public static class Rbac
{
    public const string Client = "client";
    public const string Freelancer = "freelancer";

    public static bool CanPostListing(string? role) => role == Client;

    public static bool CanSubmitProposal(string? role) => role == Freelancer;

    public static string RoleLabel(string? role) => role switch
    {
        Client => "Client",
        Freelancer => "Freelancer",
        _ => "Guest",
    };
}
