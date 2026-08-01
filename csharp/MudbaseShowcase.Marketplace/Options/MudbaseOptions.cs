namespace MudbaseShowcase.Marketplace.Options;

/// <summary>
/// Every config value this app needs to talk to a provisioned Mudbase project. Bound from the
/// "Mudbase" section of appsettings.json / environment variables - see appsettings.Example.json
/// at the repo root for the full list with descriptions. None of these values are secrets (a
/// project/collection id is not sensitive), so, unlike a real credential, they are checked into
/// appsettings.json directly - see README.md.
/// </summary>
public sealed class MudbaseOptions
{
    public const string SectionName = "Mudbase";

    /// <summary>Mudbase API base URL. Defaults to the public cloud endpoint.</summary>
    public string BaseUrl { get; set; } = "https://cloud.mudbase.dev";

    /// <summary>The Mudbase project ID this app is provisioned against.</summary>
    public string ProjectId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "listings" collection.</summary>
    public string ListingsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "proposals" collection.</summary>
    public string ProposalsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "messages" collection.</summary>
    public string MessagesCollectionId { get; set; } = string.Empty;

    /// <summary>
    /// The listings collection's slug (distinct from its _id above) - the dedicated
    /// GET /api/search/projects/:id/search endpoint's `collections` query param matches on slug,
    /// not _id. Fixed for this reference project, not configurable, mirroring
    /// web/src/lib/config.ts's LISTINGS_COLLECTION_SLUG constant.
    /// </summary>
    public string ListingsCollectionSlug => "listings";

    /// <summary>
    /// Throws with a clear, specific message if any required value was left unset, so a
    /// misconfigured deployment fails at startup instead of surfacing confusing errors deep
    /// inside a request handler.
    /// </summary>
    public void Validate()
    {
        var missing = new List<string>();

        if (string.IsNullOrWhiteSpace(BaseUrl)) missing.Add(nameof(BaseUrl));
        if (string.IsNullOrWhiteSpace(ProjectId)) missing.Add(nameof(ProjectId));
        if (string.IsNullOrWhiteSpace(ListingsCollectionId)) missing.Add(nameof(ListingsCollectionId));
        if (string.IsNullOrWhiteSpace(ProposalsCollectionId)) missing.Add(nameof(ProposalsCollectionId));
        if (string.IsNullOrWhiteSpace(MessagesCollectionId)) missing.Add(nameof(MessagesCollectionId));

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"Missing required Mudbase configuration values: {string.Join(", ", missing)}. " +
                "Set them under the \"Mudbase\" section of appsettings.json, appsettings.Development.json, " +
                "or the corresponding Mudbase__<Key> environment variables. See appsettings.Example.json.");
        }
    }
}
