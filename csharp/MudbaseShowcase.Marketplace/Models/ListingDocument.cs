using System.Text.Json.Serialization;

namespace MudbaseShowcase.Marketplace.Models;

/// <summary>Mirrors web/src/types/listing.ts's Listing document shape (`listings` collection).</summary>
public sealed class ListingDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("budget")]
    public decimal Budget { get; set; }

    [JsonPropertyName("category")]
    public string? Category { get; set; }

    /// <summary>"open" | "in_progress" | "completed". See ListingStatus.</summary>
    [JsonPropertyName("status")]
    public string Status { get; set; } = ListingStatus.Open;

    [JsonPropertyName("clientId")]
    public string ClientId { get; set; } = string.Empty;

    [JsonPropertyName("clientName")]
    public string ClientName { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>Mirrors web/src/types/listing.ts's LISTING_STATUSES/listingStatusLabel.</summary>
public static class ListingStatus
{
    public const string Open = "open";
    public const string InProgress = "in_progress";
    public const string Completed = "completed";

    public static readonly IReadOnlyList<string> All = [Open, InProgress, Completed];

    public static string Label(string status) => status switch
    {
        Open => "Open",
        InProgress => "In progress",
        Completed => "Completed",
        _ => status,
    };
}
