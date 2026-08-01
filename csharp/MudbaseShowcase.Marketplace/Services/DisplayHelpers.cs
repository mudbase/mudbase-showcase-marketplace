using System.Globalization;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>Small display-formatting helpers, ported from web/src/lib/utils.ts so both apps render the same way.</summary>
public static class DisplayHelpers
{
    /// <summary>Up to 2 uppercase letters: first letter of the first word + first letter of the last word. Mirrors utils.ts's `initials()` - every sender/author here is a denormalized name string, not a profile with an uploaded photo, so every avatar is a deterministic initials badge.</summary>
    public static string Initials(string name)
    {
        string[] parts = name.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return "?";
        char first = parts[0][0];
        char? last = parts.Length > 1 ? parts[^1][0] : null;
        return last is { } lastChar ? $"{first}{lastChar}".ToUpperInvariant() : first.ToString().ToUpperInvariant();
    }

    /// <summary>Mirrors utils.ts's `formatRelativeTime()`: "just now" / "Ns" / "Nm" / "Nh" / "Nd", falling back to a medium date past a week old.</summary>
    public static string FormatRelativeTime(DateTimeOffset timestamp)
    {
        TimeSpan diff = DateTimeOffset.UtcNow - timestamp;
        double diffSeconds = diff.TotalSeconds;

        if (diffSeconds < 5) return "just now";
        if (diffSeconds < 60) return $"{Math.Round(diffSeconds)}s";
        double diffMinutes = Math.Round(diff.TotalMinutes);
        if (diffMinutes < 60) return $"{diffMinutes}m";
        double diffHours = Math.Round(diff.TotalHours);
        if (diffHours < 24) return $"{diffHours}h";
        double diffDays = Math.Round(diff.TotalDays);
        if (diffDays < 7) return $"{diffDays}d";
        return timestamp.ToLocalTime().ToString("MMM d, yyyy", CultureInfo.InvariantCulture);
    }

    /// <summary>Mirrors utils.ts's `formatDateTime()` - used on message timestamps.</summary>
    public static string FormatDateTime(DateTimeOffset timestamp) =>
        timestamp.ToLocalTime().ToString("MMM d, yyyy h:mm tt", CultureInfo.InvariantCulture);

    /// <summary>Mirrors utils.ts's `formatCurrency()`.</summary>
    public static string FormatCurrency(decimal amount) =>
        amount.ToString("C0", CultureInfo.GetCultureInfo("en-US"));
}
