using System.Text.Json;
using Microsoft.Extensions.Options;
using Mudbase.Sdk.Api;
using Mudbase.Sdk.Client;
using MudbaseShowcase.Marketplace.Options;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>
/// Wraps Mudbase.Sdk.Api.SearchApi.SearchDataAsync - the dedicated server-side keyword search
/// endpoint (GET /api/search/projects/:projectId/search) this app's home page uses instead of the
/// collection-data `filter` param, which cannot do substring search: `$regex` (and `$text`'s
/// `$search`) are on the deployed query sanitizer's dangerous-operator blocklist and always 400
/// (see ../web/plan/build-plan.md "Platform issues discovered during the live smoke test").
///
/// Deliberately parses `response.RawContent` directly with a plain <see cref="JsonDocument"/>
/// instead of trusting the generated SDK's typed `SearchResponse`/`SearchResult` models: those
/// model `SearchResult.Item` as just `{_id, score}` with no other document fields, which does not
/// match the real endpoint's actual response contract already verified live and documented in
/// web/src/lib/mudbase.ts's SearchResponse&lt;T&gt;/SearchCollectionResult&lt;T&gt;
/// (`{results: [{collection, results: T[], pagination}], query, totalResults, executionTime}`,
/// where each `results[]` entry is a full document, not just an id/score pair). Mirrors the same
/// defensive "parse the real wire shape, not the generated typed model" approach
/// MudbaseDataService.ListAsync already uses for list reads - the authenticated HTTP call itself
/// (token attachment, 401-refresh-retry) still goes through the real SDK either way.
/// </summary>
public sealed class MudbaseSearchService
{
    private readonly ISearchApi _searchApi;
    private readonly MudbaseOptions _options;

    public MudbaseSearchService(ISearchApi searchApi, IOptions<MudbaseOptions> options)
    {
        _searchApi = searchApi;
        _options = options.Value;
    }

    /// <summary>
    /// Full-text keyword search across the listings collection's title/description. Only a
    /// keyword is accepted server-side - category/budget filters must be applied by the caller
    /// over the returned batch, same as web/src/app/page.tsx.
    /// </summary>
    public async Task<IReadOnlyList<T>> SearchAsync<T>(
        string collectionSlug, string q, int limit = 50, CancellationToken cancellationToken = default)
    {
        ISearchDataApiResponse response = await _searchApi.SearchDataAsync(
            _options.ProjectId, q, new Option<string>(collectionSlug), default, new Option<int>(limit), default, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw MudbaseApiException.From(response);
        }

        using JsonDocument doc = JsonDocument.Parse(response.RawContent);
        JsonElement root = doc.RootElement;

        List<T> items = new();
        if (root.TryGetProperty("results", out JsonElement resultsElement) && resultsElement.ValueKind == JsonValueKind.Array)
        {
            // Only one collection was requested (`collections: collectionSlug`), so there is at
            // most one entry in the outer `results` array - mirrors the reference app's
            // `searchQuery.data?.results[0]?.results`.
            JsonElement? firstCollection = resultsElement.EnumerateArray().FirstOrDefault();
            if (firstCollection is { ValueKind: JsonValueKind.Object } collectionResult &&
                collectionResult.TryGetProperty("results", out JsonElement docsElement) &&
                docsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement itemElement in docsElement.EnumerateArray())
                {
                    T? mapped = JsonSerializer.Deserialize<T>(itemElement.GetRawText(), MudbaseJson.Options);
                    if (mapped is not null) items.Add(mapped);
                }
            }
        }

        return items;
    }
}
