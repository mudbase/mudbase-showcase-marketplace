import Foundation

/// Mirrors `../web/src/types/listing.ts`'s `ListingStatus`/`LISTING_STATUSES`.
enum ListingStatus: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case open
    case inProgress = "in_progress"
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        }
    }
}

/// Mirrors `../web/src/types/listing.ts`'s `Listing` interface.
struct Listing: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
    let budget: Double
    let category: String?
    let status: ListingStatus
    let clientId: String
    let clientName: String
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        title = document.string("title") ?? ""
        description = document.string("description") ?? ""
        budget = document.double("budget") ?? 0
        category = document.string("category")
        status = ListingStatus(rawValue: document.string("status") ?? "") ?? .open
        clientId = document.string("clientId") ?? ""
        clientName = document.string("clientName") ?? ""
        createdAt = document.createdAt
    }
}

/// Draft state for the client's create/edit listing form — the Swift equivalent of the web app's
/// zod-validated `ListingFormValues` (`web/src/components/listings/ListingForm.tsx`). Validation
/// is re-implemented in `ListingFormViewModel` since this project has no zod dependency.
struct ListingDraft: Equatable {
    var title = ""
    var description = ""
    var budget: Double = 0
    var category = ""
    var status: ListingStatus = .open

    init() {}

    init(listing: Listing) {
        title = listing.title
        description = listing.description
        budget = listing.budget
        category = listing.category ?? ""
        status = listing.status
    }
}
