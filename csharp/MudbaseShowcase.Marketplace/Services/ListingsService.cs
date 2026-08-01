using Microsoft.Extensions.Options;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Options;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>Collection-specific wrapper over MudbaseDataService/MudbaseSearchService for `listings`. Mirrors web/src/app/page.tsx + listings/[id]/page.tsx + listings/new/page.tsx + listings/[id]/edit/page.tsx + listings/mine/page.tsx.</summary>
public sealed class ListingsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseSearchService _search;
    private readonly MudbaseOptions _options;

    public ListingsService(MudbaseDataService data, MudbaseSearchService search, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _search = search;
        _options = options.Value;
    }

    public Task<ListingDocument?> GetAsync(string id, CancellationToken cancellationToken = default) =>
        _data.GetAsync<ListingDocument>(_options.ListingsCollectionId, id, cancellationToken);

    /// <summary>Real server-side category/budget filter + pagination - used when no search keyword is present. See ListingBrowseFilter for how the filter dictionary is built.</summary>
    public Task<MudbaseListResult<ListingDocument>> BrowseAsync(
        IReadOnlyDictionary<string, object?> filter, int page, int limit, CancellationToken cancellationToken = default) =>
        _data.ListAsync<ListingDocument>(_options.ListingsCollectionId, filter, sort: "-createdAt", page: page, limit: limit, cancellationToken: cancellationToken);

    /// <summary>Dedicated keyword search over title/description - category/budget must be applied by the caller over the returned batch (see MudbaseSearchService's doc comment for why).</summary>
    public Task<IReadOnlyList<ListingDocument>> SearchAsync(string q, int limit, CancellationToken cancellationToken = default) =>
        _search.SearchAsync<ListingDocument>(_options.ListingsCollectionSlug, q, limit, cancellationToken);

    /// <summary>A client's own listings, most recent first.</summary>
    public Task<MudbaseListResult<ListingDocument>> ListMineAsync(string clientId, int page, int limit, CancellationToken cancellationToken = default) =>
        _data.ListAsync<ListingDocument>(
            _options.ListingsCollectionId,
            new Dictionary<string, object?> { ["clientId"] = clientId },
            sort: "-createdAt", page: page, limit: limit, cancellationToken: cancellationToken);

    /// <summary>A lightweight, unfiltered sample used only to populate the category dropdown - the SDK's ListDataAsync has no `fields` projection param, so this fetches full documents and derives distinct categories in-process, mirroring the reference app's own approach one level down (it also fetches full docs, just field-limited server-side, which this SDK cannot do).</summary>
    public async Task<IReadOnlyList<string>> DistinctCategoriesAsync(CancellationToken cancellationToken = default)
    {
        MudbaseListResult<ListingDocument> sample = await _data.ListAsync<ListingDocument>(
            _options.ListingsCollectionId, filter: null, sort: "-createdAt", page: 1, limit: 100, cancellationToken: cancellationToken);

        return sample.Items
            .Select(l => l.Category)
            .Where(c => !string.IsNullOrWhiteSpace(c))
            .Select(c => c!)
            .Distinct()
            .OrderBy(c => c, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    /// <summary>One batched query for the listing titles referenced on a page of proposals, instead of an N+1 query per proposal - mirrors web/src/app/proposals/page.tsx.</summary>
    public async Task<IReadOnlyDictionary<string, ListingDocument>> GetByIdsAsync(IReadOnlyList<string> listingIds, CancellationToken cancellationToken = default)
    {
        if (listingIds.Count == 0) return new Dictionary<string, ListingDocument>();

        MudbaseListResult<ListingDocument> result = await _data.ListAsync<ListingDocument>(
            _options.ListingsCollectionId,
            new Dictionary<string, object?> { ["_id"] = new Dictionary<string, object?> { ["$in"] = listingIds } },
            sort: "-createdAt", limit: 100, cancellationToken: cancellationToken);

        return result.Items.ToDictionary(l => l.Id);
    }

    public Task<ListingDocument> CreateAsync(
        string title, string description, decimal budget, string? category, string clientId, string clientName, CancellationToken cancellationToken = default)
    {
        Dictionary<string, object?> data = new()
        {
            ["title"] = title,
            ["description"] = description,
            ["budget"] = budget,
            ["category"] = string.IsNullOrWhiteSpace(category) ? null : category,
            ["status"] = ListingStatus.Open,
            ["clientId"] = clientId,
            ["clientName"] = clientName,
        };
        return _data.CreateAsync<ListingDocument>(_options.ListingsCollectionId, data, cancellationToken);
    }

    /// <summary>Title/description/budget/category/status only - clientId/clientName are never client-editable after creation, matching web/src/app/listings/[id]/edit/page.tsx's handleSubmit (which never sends those two fields).</summary>
    public Task<ListingDocument> UpdateAsync(
        string id, string title, string description, decimal budget, string? category, string status, CancellationToken cancellationToken = default)
    {
        Dictionary<string, object?> data = new()
        {
            ["title"] = title,
            ["description"] = description,
            ["budget"] = budget,
            ["category"] = string.IsNullOrWhiteSpace(category) ? null : category,
            ["status"] = status,
        };
        return _data.UpdateAsync<ListingDocument>(_options.ListingsCollectionId, id, data, cancellationToken);
    }
}
