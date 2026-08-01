import SwiftUI

/// Mirrors `../web/src/app/listings/mine/page.tsx` — a client's own listings with live proposal
/// counts, and a way to post a new one.
struct MyListingsView: View {
    @StateObject private var viewModel: MyListingsViewModel
    private let config: AppConfig
    private let clientId: String
    private let clientName: String
    @State private var isPresentingNewListing = false

    init(config: AppConfig, clientId: String, clientName: String) {
        self.config = config
        self.clientId = clientId
        self.clientName = clientName
        _viewModel = StateObject(wrappedValue: MyListingsViewModel(config: config, clientId: clientId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.listings.isEmpty {
                VStack(spacing: 12) {
                    Text("You haven't posted any listings yet.")
                        .foregroundStyle(.secondary)
                    Button("Post a listing") { isPresentingNewListing = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                List {
                    ForEach(viewModel.listings) { listing in
                        NavigationLink(value: ListingReference(id: listing.id)) {
                            MyListingRowView(listing: listing, proposalCount: viewModel.proposalCounts[listing.id] ?? 0)
                        }
                    }
                }
            }
        }
        .navigationTitle("My listings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Post listing", systemImage: "plus") { isPresentingNewListing = true }
            }
        }
        .sheet(isPresented: $isPresentingNewListing, onDismiss: { Task { await viewModel.load() } }) {
            NavigationStack {
                ListingFormView(config: config, clientId: clientId, clientName: clientName)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct MyListingRowView: View {
    let listing: Listing
    let proposalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(listing.title).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                ListingStatusBadge(status: listing.status)
            }
            HStack {
                Text(Formatting.money(listing.budget))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(proposalCount) proposal\(proposalCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatting.relativeTime(from: listing.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
