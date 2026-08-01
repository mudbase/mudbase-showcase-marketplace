import SwiftUI

/// Mirrors `../web/src/app/listings/[id]/page.tsx` — full listing detail, the freelancer's
/// proposal form (or their existing proposal status), the owning client's received proposals with
/// accept/reject, and the message thread (client + accepted freelancer only).
struct ListingDetailView: View {
    @StateObject private var viewModel: ListingDetailViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    let config: AppConfig

    init(config: AppConfig, listingId: String) {
        self.config = config
        _viewModel = StateObject(wrappedValue: ListingDetailViewModel(config: config, listingId: listingId))
    }

    private var user: AppUser? { sessionStore.user }
    private var isAuthenticated: Bool { user?.isGuest == false }

    private var isOwningClient: Bool {
        guard isAuthenticated, let user, let listing = viewModel.listing else { return false }
        return user.customRole == .client && listing.clientId == user.id
    }

    private var isFreelancer: Bool {
        isAuthenticated && user?.customRole == .freelancer
    }

    private var canMessage: Bool {
        guard isAuthenticated, let user, let listing = viewModel.listing else { return false }
        return listing.clientId == user.id || (isFreelancer && viewModel.acceptedFreelancerId == user.id)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load(currentUser: user) } }
            } else if let listing = viewModel.listing {
                List {
                    detailSection(for: listing)

                    if isFreelancer {
                        yourProposalSection
                    }

                    if isOwningClient {
                        Section("Proposals received") {
                            ProposalListView(config: config, listingId: listing.id)
                        }
                    }

                    if canMessage, let user {
                        Section {
                            MessageThreadView(config: config, listingId: listing.id, currentUser: user)
                        } header: {
                            Text("Messages")
                        }
                    }

                    if !isAuthenticated {
                        Section {
                            Text("Sign in to submit a proposal or message about this listing.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Listing")
        .inlineNavigationTitle()
        .task { await viewModel.load(currentUser: user) }
    }

    private func detailSection(for listing: Listing) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(listing.title).font(.title3.bold())
                    Spacer()
                    ListingStatusBadge(status: listing.status)
                }
                Text("Posted by \(listing.clientName) · \(Formatting.relativeTime(from: listing.createdAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(listing.description)
                    .font(.body)
                HStack {
                    Text(Formatting.money(listing.budget))
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if let category = listing.category, !category.isEmpty {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                if isOwningClient {
                    NavigationLink("Edit listing", value: ListingEditTarget(listing: listing))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var yourProposalSection: some View {
        Section("Your proposal") {
            if viewModel.isCheckingOwnProposal {
                ProgressView()
            } else if let ownProposal = viewModel.ownProposal {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Your rate: \(Formatting.money(ownProposal.proposedRate))")
                            .font(.subheadline)
                        Spacer()
                        ProposalStatusBadge(status: ownProposal.status)
                    }
                    Text(ownProposal.coverLetter)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            } else {
                ProposalFormView(isSubmitting: viewModel.isSubmittingProposal, errorMessage: viewModel.proposalErrorMessage) { draft in
                    if let user {
                        await viewModel.submitProposal(draft: draft, freelancer: user)
                    }
                }
            }
        }
    }
}
