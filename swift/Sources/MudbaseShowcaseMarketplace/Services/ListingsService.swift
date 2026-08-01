import Foundation
import MudbaseSDK

/// Listing reads/writes against the `listings` collection. Mirrors `../web/src/app/page.tsx`
/// (browse + search), `listings/new/page.tsx` (create), `listings/[id]/edit/page.tsx` (update),
/// and `listings/mine/page.tsx` (a client's own listings).
struct ListingsService {
    private let gateway: CollectionsGateway
    private let searchGateway: SearchGateway

    /// The collection's slug (distinct from its `_id` above) — the search endpoint's `collections`
    /// param matches on slug, not on `_id` (see `SearchGateway`).
    private static let collectionSlug = "listings"

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.listingsCollectionId)
        searchGateway = SearchGateway(projectId: config.projectId, baseURL: config.baseURL)
    }

    struct Page {
        let listings: [Listing]
        let pagination: Pagination?
    }

    /// No-keyword browse: real server-side filter + pagination — mirrors `page.tsx`'s "Branch 1".
    func browse(category: String?, minBudget: Double?, maxBudget: Double?, page: Int, limit: Int = 12) async throws -> Page {
        var filter: [String: JSONValue] = [:]
        if let category, !category.isEmpty { filter["category"] = .string(category) }
        if minBudget != nil || maxBudget != nil {
            var budgetFilter: [String: JSONValue] = [:]
            if let minBudget { budgetFilter["$gte"] = .double(minBudget) }
            if let maxBudget { budgetFilter["$lte"] = .double(maxBudget) }
            filter["budget"] = .dictionary(budgetFilter)
        }
        let result = try await gateway.list(filter: filter, sort: "-createdAt", page: page, limit: limit)
        return Page(listings: result.documents.map(Listing.init(document:)), pagination: result.pagination)
    }

    /// Keyword search via the dedicated search endpoint — category/budget are applied client-side
    /// over the returned batch, since the search endpoint has no room for additional structured
    /// filters alongside `q` (mirrors `page.tsx`'s "Branch 2").
    func search(q: String, category: String?, minBudget: Double?, maxBudget: Double?, limit: Int = 50) async throws -> [Listing] {
        let result = try await searchGateway.search(collectionSlug: Self.collectionSlug, q: q, limit: limit)
        let listings = result.documents.map(Listing.init(document:))
        return listings.filter { listing in
            if let category, !category.isEmpty, listing.category != category { return false }
            if let minBudget, listing.budget < minBudget { return false }
            if let maxBudget, listing.budget > maxBudget { return false }
            return true
        }
    }

    /// A lightweight, unfiltered sample used only to populate the category picker — avoids a
    /// dedicated "distinct categories" endpoint that Mudbase's data API doesn't expose.
    func categorySample(limit: Int = 100) async throws -> [String] {
        let result = try await gateway.list(sort: "-createdAt", limit: limit)
        let categories = result.documents.compactMap { $0.string("category") }
        return Array(Set(categories)).sorted()
    }

    func listMine(clientId: String, limit: Int = 50) async throws -> [Listing] {
        guard Formatting.isObjectId(clientId) else { return [] }
        let result = try await gateway.list(filter: ["clientId": .string(clientId)], sort: "-createdAt", limit: limit)
        return result.documents.map(Listing.init(document:))
    }

    /// Batched lookup by `_id` — the Swift equivalent of `proposals/page.tsx`'s
    /// `filter: { _id: { $in: listingIds } }`, avoiding an N+1 fetch per proposal.
    func listByIds(_ ids: [String], limit: Int = 100) async throws -> [Listing] {
        guard !ids.isEmpty else { return [] }
        let result = try await gateway.list(filter: ["_id": .dictionary(["$in": .array(ids.map(JSONValue.string))])], limit: limit)
        return result.documents.map(Listing.init(document:))
    }

    func get(id: String) async throws -> Listing {
        Listing(document: try await gateway.get(documentId: id))
    }

    @discardableResult
    func create(draft: ListingDraft, clientId: String, clientName: String) async throws -> Listing {
        let fields: [String: JSONValue?] = [
            "title": .string(draft.title),
            "description": .string(draft.description),
            "budget": .double(draft.budget),
            "category": draft.category.isEmpty ? nil : .string(draft.category),
            "status": .string(ListingStatus.open.rawValue),
            "clientId": .string(clientId),
            "clientName": .string(clientName),
        ]
        return Listing(document: try await gateway.create(fields: fields))
    }

    @discardableResult
    func update(id: String, draft: ListingDraft) async throws -> Listing {
        let fields: [String: JSONValue?] = [
            "title": .string(draft.title),
            "description": .string(draft.description),
            "budget": .double(draft.budget),
            "category": draft.category.isEmpty ? nil : .string(draft.category),
            "status": .string(draft.status.rawValue),
        ]
        return Listing(document: try await gateway.update(documentId: id, fields: fields))
    }
}
