import Foundation

/// Mirrors `../web/src/lib/utils.ts` — relative timestamps, currency formatting, initials for
/// message-avatar bubbles, and the client-side ObjectId sanity check every `...Id`-suffixed filter
/// value needs before being sent to Mudbase (see `../web/plan/build-plan.md` "Platform issues" #3:
/// the deployed query sanitizer rejects, and security-alerts on, any top-level filter field ending
/// in `Id` that isn't a real 24-char hex ObjectId).
enum Formatting {
    static func relativeTime(from date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let seconds = max(0, now.timeIntervalSince(date))

        switch seconds {
        case ..<5:
            return "just now"
        case ..<60:
            return "\(Int(seconds))s"
        case ..<3600:
            return "\(Int(seconds / 60))m"
        case ..<86400:
            return "\(Int(seconds / 3600))h"
        case ..<604800:
            return "\(Int(seconds / 86400))d"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Mirrors `formatCurrency` — USD, no fractional cents (this app's `budget`/`proposedRate`
    /// fields are always whole-dollar amounts, matching the web reference).
    static func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    static func initials(_ name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ").filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "?" }
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }

    private static let objectIdPattern = try? NSRegularExpression(pattern: "^[a-f0-9]{24}$", options: .caseInsensitive)

    /// Mudbase's query sanitizer rejects any top-level filter field ending in "Id" that isn't a
    /// real ObjectId — every `...Id`-suffixed filter value built in `Services/` is checked with
    /// this before being sent, mirroring `../web/src/lib/utils.ts`'s `isObjectId`.
    static func isObjectId(_ value: String?) -> Bool {
        guard let value, let pattern = objectIdPattern else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return pattern.firstMatch(in: value, options: [], range: range) != nil
    }
}
