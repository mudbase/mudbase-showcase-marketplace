import Foundation

/// Mirrors `../web/src/app/page.tsx`. Two branches, exactly like the web reference:
/// - No keyword: real server-side `filter` + pagination on category/budget.
/// - A keyword typed (debounced 300ms, matching the web app's `useDebounce`): the dedicated
///   search endpoint, with category/budget applied client-side over the returned batch (see
///   `ListingsService.search`'s doc comment for why).
///
/// This app simplifies the web reference's numbered-page `PaginationControls` to a "Load more"
/// button appending to the current list — a deliberate, documented adaptation to native list
/// idioms, not a missing feature; every filter/search/category behavior is otherwise identical.
@MainActor
final class BrowseListingsViewModel: ObservableObject {
    @Published var searchText = "" {
        didSet {
            guard oldValue != searchText else { return }
            scheduleDebouncedReload()
        }
    }
    @Published var selectedCategory: String? {
        didSet {
            guard oldValue != selectedCategory else { return }
            Task { await self.reload() }
        }
    }
    @Published var minBudgetText = "" {
        didSet {
            guard oldValue != minBudgetText else { return }
            Task { await self.reload() }
        }
    }
    @Published var maxBudgetText = "" {
        didSet {
            guard oldValue != maxBudgetText else { return }
            Task { await self.reload() }
        }
    }

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var categories: [String] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canLoadMore = false

    private let service: ListingsService
    private var currentPage = 1
    private var searchDebounceTask: Task<Void, Never>?
    private static let pageSize = 12

    init(config: AppConfig) {
        service = ListingsService(config: config)
    }

    private var minBudget: Double? { Double(minBudgetText) }
    private var maxBudget: Double? { Double(maxBudgetText) }
    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedSearch.isEmpty }

    private func scheduleDebouncedReload() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    func loadCategories() async {
        categories = (try? await service.categorySample()) ?? []
    }

    func reload() async {
        await load(page: 1, replacing: true)
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isSearching else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await load(page: currentPage + 1, replacing: false)
    }

    private func load(page: Int, replacing: Bool) async {
        if replacing { isLoading = true }
        errorMessage = nil
        defer { if replacing { isLoading = false } }
        do {
            if isSearching {
                let results = try await service.search(q: trimmedSearch, category: selectedCategory, minBudget: minBudget, maxBudget: maxBudget)
                listings = results
                canLoadMore = false
                currentPage = 1
            } else {
                let result = try await service.browse(category: selectedCategory, minBudget: minBudget, maxBudget: maxBudget, page: page, limit: Self.pageSize)
                listings = replacing ? result.listings : listings + result.listings
                currentPage = page
                canLoadMore = page < (result.pagination?.totalPages ?? page)
            }
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
