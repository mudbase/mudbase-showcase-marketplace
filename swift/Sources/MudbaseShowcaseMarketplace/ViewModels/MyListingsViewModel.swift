import Foundation

/// Mirrors `../web/src/app/listings/mine/page.tsx` — a client's own listings with live proposal
/// counts, fetched with one batched `$in` query across every listing on the page rather than an
/// N+1 query per listing.
@MainActor
final class MyListingsViewModel: ObservableObject {
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var proposalCounts: [String: Int] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let listingsService: ListingsService
    private let proposalsService: ProposalsService
    private let clientId: String

    init(config: AppConfig, clientId: String) {
        listingsService = ListingsService(config: config)
        proposalsService = ProposalsService(config: config)
        self.clientId = clientId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let mine = try await listingsService.listMine(clientId: clientId)
            listings = mine
            let allProposals = try await proposalsService.listForListings(mine.map(\.id))
            var counts: [String: Int] = [:]
            for proposal in allProposals {
                counts[proposal.listingId, default: 0] += 1
            }
            proposalCounts = counts
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
