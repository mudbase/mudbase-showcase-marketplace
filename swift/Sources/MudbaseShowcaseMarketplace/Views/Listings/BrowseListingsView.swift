import SwiftUI

/// Mirrors `../web/src/app/page.tsx` — the always-public listings feed (works under the anonymous
/// guest session, no sign-in required to browse).
struct BrowseListingsView: View {
    @StateObject private var viewModel: BrowseListingsViewModel

    init(config: AppConfig) {
        _viewModel = StateObject(wrappedValue: BrowseListingsViewModel(config: config))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.reload() } }
            } else {
                List {
                    filtersSection

                    if viewModel.listings.isEmpty {
                        Section {
                            EmptyStateView(message: "No listings match your filters.")
                        }
                    } else {
                        Section {
                            ForEach(viewModel.listings) { listing in
                                NavigationLink(value: ListingReference(id: listing.id)) {
                                    ListingCardView(listing: listing)
                                }
                            }
                            if viewModel.canLoadMore {
                                loadMoreRow
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search title or description")
        .navigationTitle("Find your next project")
        .task {
            await viewModel.loadCategories()
            await viewModel.reload()
        }
        .refreshable { await viewModel.reload() }
    }

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Category", selection: $viewModel.selectedCategory) {
                Text("All categories").tag(String?.none)
                ForEach(viewModel.categories, id: \.self) { category in
                    Text(category).tag(String?.some(category))
                }
            }
            HStack {
                TextField("Min budget", text: $viewModel.minBudgetText)
                    .numberPadKeyboard()
                Text("–")
                    .foregroundStyle(.secondary)
                TextField("Max budget", text: $viewModel.maxBudgetText)
                    .numberPadKeyboard()
            }
        }
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMore {
                ProgressView()
            } else {
                Button("Load more") { Task { await viewModel.loadMore() } }
            }
            Spacer()
        }
    }
}
