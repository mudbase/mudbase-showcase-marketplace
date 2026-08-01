using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages;

/// <summary>Freelancer-only: this freelancer's own proposals across all listings, with status. Mirrors web/src/app/proposals/page.tsx.</summary>
public sealed class ProposalsModel : PageModel
{
    private const int PageSize = 10;

    private readonly ProposalsService _proposals;
    private readonly ListingsService _listings;
    private readonly MudbaseSessionAccessor _session;

    public ProposalsModel(ProposalsService proposals, ListingsService listings, MudbaseSessionAccessor session)
    {
        _proposals = proposals;
        _listings = listings;
        _session = session;
    }

    // Named "PageNumber" (not "Page") to avoid hiding PageModel.Page() (CS0108) - see IndexModel.
    [BindProperty(SupportsGet = true, Name = "Page")]
    public int PageNumber { get; set; } = 1;

    public bool IsForbidden { get; private set; }

    public string? LoadError { get; private set; }

    public IReadOnlyList<ProposalDocument> Proposals { get; private set; } = Array.Empty<ProposalDocument>();

    public IReadOnlyDictionary<string, ListingDocument> ListingsById { get; private set; } = new Dictionary<string, ListingDocument>();

    public int TotalPages { get; private set; } = 1;

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        if (PageNumber < 1) PageNumber = 1;

        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsFreelancer: true })
        {
            IsForbidden = true;
            return;
        }

        try
        {
            MudbaseListResult<ProposalDocument> result = await _proposals.ListMineAsync(user.Id, PageNumber, PageSize, cancellationToken);
            Proposals = result.Items;
            TotalPages = Math.Max(1, result.TotalPages);

            List<string> listingIds = Proposals.Select(p => p.ListingId).Distinct().ToList();
            ListingsById = await _listings.GetByIdsAsync(listingIds, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load your proposals. (" + ex.Message + ")";
        }
    }
}
