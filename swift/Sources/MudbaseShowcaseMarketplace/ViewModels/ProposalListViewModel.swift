import Foundation

/// Mirrors `../web/src/components/proposals/ProposalList.tsx` — the owning client's view of every
/// proposal on one listing, with one-tap accept/reject.
@MainActor
final class ProposalListViewModel: ObservableObject {
    @Published private(set) var proposals: [Proposal] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var actioningId: String?

    private let service: ProposalsService
    private let listingId: String

    init(config: AppConfig, listingId: String) {
        service = ProposalsService(config: config)
        self.listingId = listingId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            proposals = try await service.listForListing(listingId)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }

    func setStatus(_ proposal: Proposal, status: ProposalStatus) async {
        actioningId = proposal.id
        defer { actioningId = nil }
        do {
            try await service.setStatus(proposal.id, status: status)
            await load()
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
