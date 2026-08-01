import Foundation

/// `navigationDestination(for:)` registers one destination builder per *type* within a given
/// `NavigationStack`. These small wrapper types give each navigation edge its own type so a
/// listing's detail push and its edit push (both ultimately about the same `Listing`) can never be
/// confused with one another, and so every tab's stack (Browse, My Listings, My Proposals) can
/// push to listing detail with nothing more than an id.
struct ListingReference: Hashable {
    let id: String
}

/// Edit needs the full `Listing` value to prefill `ListingFormViewModel`'s draft — only ever
/// constructed from inside `ListingDetailView`, where the full object is already in hand.
struct ListingEditTarget: Hashable {
    let listing: Listing
}
