using System.Text.Json.Serialization;

namespace MudbaseShowcase.Marketplace.Models;

/// <summary>Mirrors web/src/types/proposal.ts's Proposal document shape (`proposals` collection).</summary>
public sealed class ProposalDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("listingId")]
    public string ListingId { get; set; } = string.Empty;

    [JsonPropertyName("freelancerId")]
    public string FreelancerId { get; set; } = string.Empty;

    [JsonPropertyName("freelancerName")]
    public string FreelancerName { get; set; } = string.Empty;

    [JsonPropertyName("coverLetter")]
    public string CoverLetter { get; set; } = string.Empty;

    [JsonPropertyName("proposedRate")]
    public decimal ProposedRate { get; set; }

    /// <summary>"pending" | "accepted" | "rejected". See ProposalStatus.</summary>
    [JsonPropertyName("status")]
    public string Status { get; set; } = ProposalStatus.Pending;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>Mirrors web/src/types/proposal.ts's PROPOSAL_STATUSES/proposalStatusLabel.</summary>
public static class ProposalStatus
{
    public const string Pending = "pending";
    public const string Accepted = "accepted";
    public const string Rejected = "rejected";

    public static string Label(string status) => status switch
    {
        Pending => "Pending",
        Accepted => "Accepted",
        Rejected => "Rejected",
        _ => status,
    };
}
