import Foundation

/// Mirrors `../web/src/app/proposals/page.tsx` — a freelancer's own proposals across every
/// listing, with a batched `$in` lookup for the referenced listing titles instead of an N+1 fetch
/// per proposal.
@MainActor
final class MyProposalsViewModel: ObservableObject {
    @Published private(set) var proposals: [Proposal] = []
    @Published private(set) var listingTitles: [String: String] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let proposalsService: ProposalsService
    private let listingsService: ListingsService
    private let freelancerId: String

    init(config: AppConfig, freelancerId: String) {
        proposalsService = ProposalsService(config: config)
        listingsService = ListingsService(config: config)
        self.freelancerId = freelancerId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let mine = try await proposalsService.listMine(freelancerId: freelancerId)
            proposals = mine
            let listingIds = Array(Set(mine.map(\.listingId)))
            let listings = try await listingsService.listByIds(listingIds)
            listingTitles = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0.title) })
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
