import Foundation

/// Mirrors `../web/src/types/proposal.ts`'s `ProposalStatus`/`PROPOSAL_STATUSES`.
enum ProposalStatus: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case pending
    case accepted
    case rejected

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Mirrors `../web/src/types/proposal.ts`'s `Proposal` interface.
struct Proposal: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let listingId: String
    let freelancerId: String
    let freelancerName: String
    let coverLetter: String
    let proposedRate: Double
    let status: ProposalStatus
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        listingId = document.string("listingId") ?? ""
        freelancerId = document.string("freelancerId") ?? ""
        freelancerName = document.string("freelancerName") ?? ""
        coverLetter = document.string("coverLetter") ?? ""
        proposedRate = document.double("proposedRate") ?? 0
        status = ProposalStatus(rawValue: document.string("status") ?? "") ?? .pending
        createdAt = document.createdAt
    }
}

/// Draft state for the freelancer's proposal-submission form — the Swift equivalent of the web
/// app's zod-validated `ProposalFormValues` (`web/src/components/proposals/ProposalForm.tsx`).
struct ProposalDraft: Equatable {
    var coverLetter = ""
    var proposedRate: Double = 0
}
