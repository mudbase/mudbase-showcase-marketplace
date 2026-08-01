using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages.Listings;

/// <summary>Client-only: this client's own listings with live proposal counts. Mirrors web/src/app/listings/mine/page.tsx.</summary>
public sealed class MineModel : PageModel
{
    private const int PageSize = 10;

    private readonly ListingsService _listings;
    private readonly ProposalsService _proposals;
    private readonly MudbaseSessionAccessor _session;

    public MineModel(ListingsService listings, ProposalsService proposals, MudbaseSessionAccessor session)
    {
        _listings = listings;
        _proposals = proposals;
        _session = session;
    }

    // Named "PageNumber" (not "Page") to avoid hiding PageModel.Page() (CS0108) - see IndexModel.
    [BindProperty(SupportsGet = true, Name = "Page")]
    public int PageNumber { get; set; } = 1;

    public bool IsForbidden { get; private set; }

    public string? LoadError { get; private set; }

    public IReadOnlyList<ListingDocument> Listings { get; private set; } = Array.Empty<ListingDocument>();

    public IReadOnlyDictionary<string, int> ProposalCounts { get; private set; } = new Dictionary<string, int>();

    public int TotalPages { get; private set; } = 1;

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        if (PageNumber < 1) PageNumber = 1;

        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsClient: true })
        {
            IsForbidden = true;
            return;
        }

        try
        {
            MudbaseListResult<ListingDocument> result = await _listings.ListMineAsync(user.Id, PageNumber, PageSize, cancellationToken);
            Listings = result.Items;
            TotalPages = Math.Max(1, result.TotalPages);

            // One batched query for proposal counts across every listing on this page, instead of
            // an N+1 query per listing.
            ProposalCounts = await _proposals.CountByListingAsync(Listings.Select(l => l.Id).ToList(), cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load your listings. (" + ex.Message + ")";
        }
    }
}
