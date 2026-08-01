import Foundation
import MudbaseSDK

/// Proposal reads/writes against the `proposals` collection. Mirrors
/// `../web/src/components/proposals/ProposalForm.tsx` (create), `ProposalList.tsx` (client's
/// accept/reject), and `proposals/page.tsx` (a freelancer's own proposals).
struct ProposalsService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.proposalsCollectionId)
    }

    func listForListing(_ listingId: String, limit: Int = 100) async throws -> [Proposal] {
        guard Formatting.isObjectId(listingId) else { return [] }
        let result = try await gateway.list(filter: ["listingId": .string(listingId)], sort: "-createdAt", limit: limit)
        return result.documents.map(Proposal.init(document:))
    }

    func listMine(freelancerId: String, limit: Int = 100) async throws -> [Proposal] {
        guard Formatting.isObjectId(freelancerId) else { return [] }
        let result = try await gateway.list(filter: ["freelancerId": .string(freelancerId)], sort: "-createdAt", limit: limit)
        return result.documents.map(Proposal.init(document:))
    }

    /// Batched lookup across every listing on a page — the Swift equivalent of
    /// `listings/mine/page.tsx`'s `filter: { listingId: { $in: listingIds } }`, avoiding an N+1
    /// proposal-count fetch per listing.
    func listForListings(_ listingIds: [String], limit: Int = 100) async throws -> [Proposal] {
        guard !listingIds.isEmpty else { return [] }
        let result = try await gateway.list(filter: ["listingId": .dictionary(["$in": .array(listingIds.map(JSONValue.string))])], limit: limit)
        return result.documents.map(Proposal.init(document:))
    }

    /// The freelancer's own proposal on this listing, if any — decides whether the listing detail
    /// screen shows the submission form or the existing status.
    func ownProposal(listingId: String, freelancerId: String) async throws -> Proposal? {
        guard Formatting.isObjectId(listingId), Formatting.isObjectId(freelancerId) else { return nil }
        let result = try await gateway.list(filter: ["listingId": .string(listingId), "freelancerId": .string(freelancerId)], limit: 1)
        return result.documents.first.map(Proposal.init(document:))
    }

    /// Whichever proposal has been accepted on this listing, if any — decides message-thread
    /// access for a non-owning freelancer (see `plan/build-plan.md` "Messaging visibility").
    func acceptedProposal(listingId: String) async throws -> Proposal? {
        guard Formatting.isObjectId(listingId) else { return nil }
        let result = try await gateway.list(filter: ["listingId": .string(listingId), "status": .string(ProposalStatus.accepted.rawValue)], limit: 1)
        return result.documents.first.map(Proposal.init(document:))
    }

    @discardableResult
    func create(draft: ProposalDraft, listingId: String, freelancerId: String, freelancerName: String) async throws -> Proposal {
        let fields: [String: JSONValue?] = [
            "listingId": .string(listingId),
            "freelancerId": .string(freelancerId),
            "freelancerName": .string(freelancerName),
            "coverLetter": .string(draft.coverLetter),
            "proposedRate": .double(draft.proposedRate),
            "status": .string(ProposalStatus.pending.rawValue),
        ]
        return Proposal(document: try await gateway.create(fields: fields))
    }

    func setStatus(_ id: String, status: ProposalStatus) async throws {
        try await gateway.update(documentId: id, fields: ["status": .string(status.rawValue)])
    }
}
