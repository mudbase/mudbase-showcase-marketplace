import Foundation

/// Mirrors `../web/src/app/listings/[id]/page.tsx` — listing detail, the freelancer's own
/// proposal-or-submission-form, and the accepted-proposal check that decides message-thread
/// access (see `plan/build-plan.md` "Messaging visibility").
@MainActor
final class ListingDetailViewModel: ObservableObject {
    @Published private(set) var listing: Listing?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    @Published private(set) var ownProposal: Proposal?
    @Published private(set) var isCheckingOwnProposal = false
    @Published private(set) var acceptedFreelancerId: String?

    @Published private(set) var isSubmittingProposal = false
    @Published var proposalErrorMessage: String?

    private let listingsService: ListingsService
    private let proposalsService: ProposalsService
    let listingId: String

    init(config: AppConfig, listingId: String) {
        listingsService = ListingsService(config: config)
        proposalsService = ProposalsService(config: config)
        self.listingId = listingId
    }

    func load(currentUser: AppUser?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            listing = try await listingsService.get(id: listingId)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
            return
        }

        // Whichever proposal has been accepted on this listing, if any - decides who besides the
        // client can see and use the message thread.
        acceptedFreelancerId = (try? await proposalsService.acceptedProposal(listingId: listingId))?.freelancerId

        if let currentUser, currentUser.customRole == .freelancer {
            isCheckingOwnProposal = true
            ownProposal = try? await proposalsService.ownProposal(listingId: listingId, freelancerId: currentUser.id)
            isCheckingOwnProposal = false
        }
    }

    func submitProposal(draft: ProposalDraft, freelancer: AppUser) async {
        isSubmittingProposal = true
        proposalErrorMessage = nil
        defer { isSubmittingProposal = false }
        do {
            let created = try await proposalsService.create(draft: draft, listingId: listingId, freelancerId: freelancer.id, freelancerName: freelancer.displayName)
            ownProposal = created
        } catch {
            proposalErrorMessage = MudbaseAPIError.map(error).message
        }
    }
}
