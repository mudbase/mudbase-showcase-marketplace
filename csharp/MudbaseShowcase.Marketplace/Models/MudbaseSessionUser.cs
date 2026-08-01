using System.Text.Json.Serialization;

namespace MudbaseShowcase.Marketplace.Models;

/// <summary>
/// The authenticated user info this app cares about, parsed from Mudbase's session/user payload
/// (which the generated SDK types loosely as `Object` - see
/// <see cref="MudbaseShowcase.Marketplace.Services.MudbaseAuthService"/>). Mirrors
/// web/src/lib/mudbase.ts's UserObject. Unlike the kanban/events C# ports, this app DOES carry an
/// anonymous/guest session (see Infrastructure/EnsureMudbaseSessionMiddleware.cs) so the listings
/// feed can be browsed without signing in - mirrors the "IsAnonymous" flag already established in
/// the ecommerce/social C# ports.
/// </summary>
public sealed class MudbaseSessionUser
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("firstName")]
    public string FirstName { get; set; } = string.Empty;

    [JsonPropertyName("lastName")]
    public string LastName { get; set; } = string.Empty;

    [JsonPropertyName("role")]
    public string? Role { get; set; }

    /// <summary>Mudbase Multi-Role customRole - "client" or "freelancer" for this project. See Services/Rbac.cs.</summary>
    [JsonPropertyName("customRole")]
    public string? CustomRole { get; set; }

    [JsonPropertyName("emailVerified")]
    public bool EmailVerified { get; set; }

    [JsonPropertyName("isAnonymous")]
    public bool? IsAnonymous { get; set; }

    public bool IsClient => CustomRole == Services.Rbac.Client;

    public bool IsFreelancer => CustomRole == Services.Rbac.Freelancer;

    /// <summary>
    /// True for a real, role-carrying account - distinct from the always-present anonymous guest
    /// session. Mirrors useAuth.ts's isAuthenticated: `!!user && user.isAnonymous !== true && !!role`.
    /// </summary>
    public bool IsSignedIn => IsAnonymous != true && (IsClient || IsFreelancer);

    /// <summary>"First Last", trimmed - used as the denormalized clientName/freelancerName/senderName written to every collection row this user creates.</summary>
    public string DisplayName => $"{FirstName} {LastName}".Trim();
}
