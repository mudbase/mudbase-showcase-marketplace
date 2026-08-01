using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages.Listings;

/// <summary>
/// Full listing detail: proposal submission (freelancer), proposals list + accept/reject (owning
/// client), and the message thread (client + accepted freelancer). Mirrors
/// web/src/app/listings/[id]/page.tsx.
///
/// SECURITY: every mutating handler below (OnPostAcceptAsync, OnPostRejectAsync,
/// OnPostSendMessageAsync, OnPostProposeAsync) re-derives ownership from a document freshly
/// fetched from Mudbase in that same request - never from a hidden form field, the page's own
/// rendered state, or anything else the client controls. This is the exact discipline the sibling
/// mudbase-showcase-events/csharp port's csharp-reviewer pass found missing (a booking-cancellation
/// handler trusted a hidden eventId/capacity form field with no server-side ownership check - a
/// real IDOR). See OnPostAcceptAsync/OnPostRejectAsync in particular: `proposalId` is the only
/// client-supplied identifier trusted - the listing it belongs to, and that listing's clientId,
/// are both re-fetched from Mudbase before any write.
/// </summary>
public sealed class DetailModel : PageModel
{
    private readonly ListingsService _listings;
    private readonly ProposalsService _proposals;
    private readonly MessagesService _messages;
    private readonly MudbaseSessionAccessor _session;

    public DetailModel(ListingsService listings, ProposalsService proposals, MessagesService messages, MudbaseSessionAccessor session)
    {
        _listings = listings;
        _proposals = proposals;
        _messages = messages;
        _session = session;
    }

    public ListingDocument? Listing { get; private set; }

    public bool IsNotFound { get; private set; }

    public string? LoadError { get; private set; }

    public bool IsOwningClient { get; private set; }

    public bool IsFreelancer { get; private set; }

    public bool CanMessage { get; private set; }

    public ProposalDocument? OwnProposal { get; private set; }

    public IReadOnlyList<ProposalDocument> ReceivedProposals { get; private set; } = Array.Empty<ProposalDocument>();

    public IReadOnlyList<MessageDocument> Messages { get; private set; } = Array.Empty<MessageDocument>();

    [BindProperty]
    public ProposalInput ProposalForm { get; set; } = new();

    [BindProperty]
    public string MessageDraft { get; set; } = string.Empty;

    [TempData]
    public string? FlashError { get; set; }

    public async Task<IActionResult> OnGetAsync(string id, CancellationToken cancellationToken)
    {
        await LoadAsync(id, cancellationToken);
        return Page();
    }

    /// <summary>
    /// Freelancer submits a proposal. Re-checks role and re-runs GetOwnAsync server-side
    /// immediately before creating - guards a double-submit from creating two proposals for the
    /// same freelancer/listing, mirroring the fix the sibling Events port applied to its own
    /// double-booking gap (never trust the GET-rendered "already applied" state).
    /// </summary>
    public async Task<IActionResult> OnPostProposeAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsFreelancer: true })
        {
            FlashError = "Sign in with a freelancer account to submit a proposal.";
            return RedirectToPage(new { id });
        }

        if (!ModelState.IsValid)
        {
            await LoadAsync(id, cancellationToken);
            return Page();
        }

        try
        {
            ProposalDocument? existing = await _proposals.GetOwnAsync(id, user.Id, cancellationToken);
            if (existing is not null)
            {
                FlashError = "You've already submitted a proposal for this listing.";
                return RedirectToPage(new { id });
            }

            await _proposals.CreateAsync(id, user.Id, user.DisplayName, ProposalForm.CoverLetter, ProposalForm.ProposedRate, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't submit your proposal. (" + ex.Message + ")";
        }

        return RedirectToPage(new { id });
    }

    /// <summary>
    /// Only `proposalId` is trusted from the client - the proposal (and the listing it belongs to)
    /// are re-fetched from Mudbase, and the current user must be that listing's `clientId`, before
    /// SetStatusAsync is ever called. A tampered `proposalId` belonging to someone else's listing
    /// is rejected here, before Mudbase's own collection permissions would even see the request.
    /// </summary>
    public Task<IActionResult> OnPostAcceptAsync(string id, string proposalId, CancellationToken cancellationToken) =>
        SetProposalStatusAsync(id, proposalId, ProposalStatus.Accepted, cancellationToken);

    /// <summary>See OnPostAcceptAsync's doc comment - identical ownership re-derivation.</summary>
    public Task<IActionResult> OnPostRejectAsync(string id, string proposalId, CancellationToken cancellationToken) =>
        SetProposalStatusAsync(id, proposalId, ProposalStatus.Rejected, cancellationToken);

    private async Task<IActionResult> SetProposalStatusAsync(string id, string proposalId, string newStatus, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsClient: true })
        {
            FlashError = "Only the client who posted this listing can review proposals.";
            return RedirectToPage(new { id });
        }

        try
        {
            ProposalDocument? proposal = await _proposals.GetAsync(proposalId, cancellationToken);
            if (proposal is null || proposal.ListingId != id)
            {
                FlashError = "That proposal no longer exists.";
                return RedirectToPage(new { id });
            }

            ListingDocument? listing = await _listings.GetAsync(id, cancellationToken);
            if (listing is null)
            {
                FlashError = "This listing no longer exists.";
                return RedirectToPage(new { id });
            }

            if (listing.ClientId != user.Id)
            {
                FlashError = "You can only review proposals on your own listings.";
                return RedirectToPage(new { id });
            }

            await _proposals.SetStatusAsync(proposal.Id, newStatus, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't update this proposal. (" + ex.Message + ")";
        }

        return RedirectToPage(new { id });
    }

    /// <summary>
    /// Re-derives messaging eligibility server-side (owning client, or the freelancer with the
    /// accepted proposal on this listing) from freshly fetched documents before ever writing a
    /// message - never trusts a hidden "canMessage" flag, since the same class of hidden-field
    /// trust caused the IDOR fixed in the sibling Events port.
    /// </summary>
    public async Task<IActionResult> OnPostSendMessageAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            FlashError = "Sign in to send a message.";
            return RedirectToPage(new { id });
        }

        string content = MessageDraft?.Trim() ?? string.Empty;
        if (content.Length == 0)
        {
            return RedirectToPage(new { id });
        }

        try
        {
            ListingDocument? listing = await _listings.GetAsync(id, cancellationToken);
            if (listing is null)
            {
                FlashError = "This listing no longer exists.";
                return RedirectToPage(new { id });
            }

            bool isOwningClient = user.IsClient && listing.ClientId == user.Id;
            bool isAcceptedFreelancer = false;
            if (user.IsFreelancer)
            {
                ProposalDocument? accepted = await _proposals.GetAcceptedAsync(id, cancellationToken);
                isAcceptedFreelancer = accepted?.FreelancerId == user.Id;
            }

            if (!isOwningClient && !isAcceptedFreelancer)
            {
                FlashError = "You don't have access to this listing's messages.";
                return RedirectToPage(new { id });
            }

            await _messages.CreateAsync(id, user.Id, user.DisplayName, content, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            FlashError = "Couldn't send your message. (" + ex.Message + ")";
        }

        return RedirectToPage(new { id });
    }

    private async Task LoadAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;

        try
        {
            Listing = await _listings.GetAsync(id, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load this listing. (" + ex.Message + ")";
            return;
        }

        if (Listing is null)
        {
            IsNotFound = true;
            return;
        }

        IsOwningClient = user is { IsClient: true } && Listing.ClientId == user.Id;
        IsFreelancer = user is { IsFreelancer: true };

        try
        {
            if (IsFreelancer && user is not null)
            {
                OwnProposal = await _proposals.GetOwnAsync(id, user.Id, cancellationToken);
            }

            if (IsOwningClient)
            {
                MudbaseListResult<ProposalDocument> received = await _proposals.ListForListingAsync(id, cancellationToken);
                ReceivedProposals = received.Items;
            }

            ProposalDocument? acceptedProposal = await _proposals.GetAcceptedAsync(id, cancellationToken);
            CanMessage = IsOwningClient || (IsFreelancer && user is not null && acceptedProposal?.FreelancerId == user.Id);

            if (CanMessage)
            {
                MudbaseListResult<MessageDocument> thread = await _messages.ListForListingAsync(id, cancellationToken);
                Messages = thread.Items;
            }
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Some details on this page couldn't be loaded. (" + ex.Message + ")";
        }
    }

    public sealed class ProposalInput
    {
        [Required(ErrorMessage = "Cover letter is required"), MinLength(20, ErrorMessage = "Cover letter must be at least 20 characters")]
        public string CoverLetter { get; set; } = string.Empty;

        [Range(typeof(decimal), "0.01", "79228162514264337593543950335", ErrorMessage = "Proposed rate must be greater than 0")]
        public decimal ProposedRate { get; set; }
    }
}
