import SwiftUI

/// Registers the two cross-tab navigation destinations (listing detail, listing edit) once per
/// `NavigationStack` — applied to every tab's root stack in `MainTabView` (Browse, My Listings,
/// My Proposals all push to listing detail with nothing more than an id).
extension View {
    func marketplaceNavigationDestinations(config: AppConfig) -> some View {
        self
            .navigationDestination(for: ListingReference.self) { reference in
                ListingDetailView(config: config, listingId: reference.id)
            }
            .navigationDestination(for: ListingEditTarget.self) { target in
                ListingFormView(
                    config: config,
                    clientId: target.listing.clientId,
                    clientName: target.listing.clientName,
                    existingListing: target.listing
                )
            }
    }
}
