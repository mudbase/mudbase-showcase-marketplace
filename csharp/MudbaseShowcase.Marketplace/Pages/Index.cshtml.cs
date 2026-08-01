using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages;

/// <summary>
/// Browse listings - search, category filter, budget range, pagination. Mirrors
/// web/src/app/page.tsx + ListingFilters.tsx + ListingCard.tsx.
/// </summary>
public sealed class IndexModel : PageModel
{
    private const int PageSize = 12;

    private readonly ListingsService _listings;

    public IndexModel(ListingsService listings)
    {
        _listings = listings;
    }

    [BindProperty(SupportsGet = true)]
    public string? Search { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Category { get; set; }

    [BindProperty(SupportsGet = true)]
    public decimal? MinBudget { get; set; }

    [BindProperty(SupportsGet = true)]
    public decimal? MaxBudget { get; set; }

    // Named "PageNumber" (not "Page") - PageModel already declares a Page() method for
    // returning a PageResult, and a same-named property would hide it (CS0108). The bound query
    // string param name stays "Page" via the BindProperty Name override so the URL is unaffected.
    [BindProperty(SupportsGet = true, Name = "Page")]
    public int PageNumber { get; set; } = 1;

    public IReadOnlyList<ListingDocument> Listings { get; private set; } = Array.Empty<ListingDocument>();

    public IReadOnlyList<string> Categories { get; private set; } = Array.Empty<string>();

    public int TotalPages { get; private set; } = 1;

    public string? LoadError { get; private set; }

    private bool IsSearching => !string.IsNullOrWhiteSpace(Search);

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        if (PageNumber < 1) PageNumber = 1;

        try
        {
            Categories = await _listings.DistinctCategoriesAsync(cancellationToken);

            if (IsSearching)
            {
                // Dedicated keyword search endpoint - category/budget applied in-process over the
                // returned batch, and pagination is likewise done in-process, since the search
                // endpoint doesn't accept additional structured filters alongside `q`. Mirrors
                // web/src/app/page.tsx's "Branch 2".
                IReadOnlyList<ListingDocument> all = await _listings.SearchAsync(Search!.Trim(), limit: 50, cancellationToken);
                List<ListingDocument> filtered = all.Where(MatchesFilters).ToList();

                TotalPages = Math.Max(1, (int)Math.Ceiling(filtered.Count / (double)PageSize));
                Listings = filtered.Skip((PageNumber - 1) * PageSize).Take(PageSize).ToList();
            }
            else
            {
                // No keyword - real server-side category/budget filter + pagination. Mirrors
                // web/src/app/page.tsx's "Branch 1".
                Dictionary<string, object?> filter = new();
                if (!string.IsNullOrWhiteSpace(Category)) filter["category"] = Category;

                if (MinBudget is { } min || MaxBudget is { } max)
                {
                    Dictionary<string, object?> budgetRange = new();
                    if (MinBudget is { } minValue) budgetRange["$gte"] = minValue;
                    if (MaxBudget is { } maxValue) budgetRange["$lte"] = maxValue;
                    filter["budget"] = budgetRange;
                }

                MudbaseListResult<ListingDocument> result = await _listings.BrowseAsync(filter, PageNumber, PageSize, cancellationToken);
                Listings = result.Items;
                TotalPages = Math.Max(1, result.TotalPages);
            }
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load listings right now. Please try again. (" + ex.Message + ")";
        }
    }

    private bool MatchesFilters(ListingDocument listing)
    {
        if (!string.IsNullOrWhiteSpace(Category) && listing.Category != Category) return false;
        if (MinBudget is { } min && listing.Budget < min) return false;
        if (MaxBudget is { } max && listing.Budget > max) return false;
        return true;
    }
}
