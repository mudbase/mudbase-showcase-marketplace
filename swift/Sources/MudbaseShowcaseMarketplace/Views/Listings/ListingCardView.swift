import SwiftUI

/// Mirrors `../web/src/components/listings/ListingCard.tsx` (a browse-grid card).
struct ListingCardView: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                ListingStatusBadge(status: listing.status)
            }
            Text(listing.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(Formatting.money(listing.budget))
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
                if let category = listing.category, !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Spacer()
                Text(listing.clientName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
