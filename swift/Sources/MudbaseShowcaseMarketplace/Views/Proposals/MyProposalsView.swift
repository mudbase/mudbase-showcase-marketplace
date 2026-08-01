import SwiftUI

/// Mirrors `../web/src/app/proposals/page.tsx` — a freelancer's own proposals across every
/// listing.
struct MyProposalsView: View {
    @StateObject private var viewModel: MyProposalsViewModel

    init(config: AppConfig, freelancerId: String) {
        _viewModel = StateObject(wrappedValue: MyProposalsViewModel(config: config, freelancerId: freelancerId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.proposals.isEmpty {
                EmptyStateView(message: "You haven't submitted any proposals yet. Browse listings to get started.")
            } else {
                List {
                    ForEach(viewModel.proposals) { proposal in
                        NavigationLink(value: ListingReference(id: proposal.listingId)) {
                            MyProposalRowView(proposal: proposal, listingTitle: viewModel.listingTitles[proposal.listingId] ?? "Listing")
                        }
                    }
                }
            }
        }
        .navigationTitle("My proposals")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct MyProposalRowView: View {
    let proposal: Proposal
    let listingTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(listingTitle).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                ProposalStatusBadge(status: proposal.status)
            }
            HStack {
                Text("Your rate: \(Formatting.money(proposal.proposedRate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatting.relativeTime(from: proposal.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
