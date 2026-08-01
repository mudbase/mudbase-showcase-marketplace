import SwiftUI

/// Mirrors `../web/src/components/proposals/ProposalList.tsx` — embedded inside
/// `ListingDetailView`'s "Proposals received" section (only rendered for the owning client),
/// so this renders a plain `VStack` of cards rather than owning its own `List`.
struct ProposalListView: View {
    @StateObject private var viewModel: ProposalListViewModel

    init(config: AppConfig, listingId: String) {
        _viewModel = StateObject(wrappedValue: ProposalListViewModel(config: config, listingId: listingId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.proposals.isEmpty {
                Text("No proposals yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.proposals) { proposal in
                    ProposalRowView(
                        proposal: proposal,
                        isActioning: viewModel.actioningId == proposal.id
                    ) { status in
                        await viewModel.setStatus(proposal, status: status)
                    }
                    if proposal.id != viewModel.proposals.last?.id {
                        Divider()
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

private struct ProposalRowView: View {
    let proposal: Proposal
    let isActioning: Bool
    let onSetStatus: (ProposalStatus) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.freelancerName).font(.subheadline.bold())
                    Text("\(Formatting.money(proposal.proposedRate)) · \(Formatting.relativeTime(from: proposal.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProposalStatusBadge(status: proposal.status)
            }
            Text(proposal.coverLetter)
                .font(.subheadline)
            if proposal.status == .pending {
                HStack {
                    Button("Accept") { Task { await onSetStatus(.accepted) } }
                        .buttonStyle(.borderedProminent)
                    Button("Reject", role: .destructive) { Task { await onSetStatus(.rejected) } }
                        .buttonStyle(.bordered)
                }
                .disabled(isActioning)
            }
        }
        .padding(.vertical, 6)
    }
}
