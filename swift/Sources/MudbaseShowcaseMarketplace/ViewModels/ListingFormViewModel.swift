import Foundation

/// Mirrors `../web/src/components/listings/ListingForm.tsx`'s zod schema — re-implemented as plain
/// validation since this project has no zod dependency. Handles both "Post a new listing" and
/// "Edit listing" (an `existingListing` switches the save path from `create` to `update`, exactly
/// like `listings/new/page.tsx` vs. `listings/[id]/edit/page.tsx`).
@MainActor
final class ListingFormViewModel: ObservableObject {
    @Published var draft: ListingDraft
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSave = false
    @Published private(set) var savedListingId: String?

    private let service: ListingsService
    private let clientId: String
    private let clientName: String
    private let existingListingId: String?

    let isEditing: Bool

    init(config: AppConfig, clientId: String, clientName: String, existingListing: Listing? = nil) {
        service = ListingsService(config: config)
        self.clientId = clientId
        self.clientName = clientName
        existingListingId = existingListing?.id
        isEditing = existingListing != nil
        draft = existingListing.map(ListingDraft.init(listing:)) ?? ListingDraft()
    }

    private var validationError: String? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count < 3 { return "Title must be at least 3 characters" }
        if title.count > 120 { return "Title is too long" }
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.count < 20 { return "Description must be at least 20 characters" }
        if draft.budget <= 0 { return "Budget must be greater than 0" }
        if draft.category.count > 60 { return "Category is too long" }
        return nil
    }

    func save() async {
        if let validationError {
            errorMessage = validationError
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            if let existingListingId {
                let updated = try await service.update(id: existingListingId, draft: draft)
                savedListingId = updated.id
            } else {
                let created = try await service.create(draft: draft, clientId: clientId, clientName: clientName)
                savedListingId = created.id
            }
            didSave = true
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
