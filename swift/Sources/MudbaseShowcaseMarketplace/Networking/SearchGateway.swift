import Foundation
import MudbaseSDK

/// Calls the dedicated `GET /api/search/projects/:projectId/search` endpoint directly with
/// `URLSession`, NOT through the generated SDK's `SearchAPI.searchData` — that call's generated
/// response models (`SearchResponse` / `SearchResponseData` / `SearchResult` / `SearchResultItem`:
/// `{ success, data: { results: [{ collection: String?, item: { id, score } }], pagination,
/// query, searchTime } }`) do **not** match what the endpoint actually returns. Confirmed by
/// reading the real handler directly, not by guessing: `mudbase-backend/routes/search.js`'s
/// `GET /projects/:projectId/search` calls `searchService.executeSearch`
/// (`mudbase-backend/services/searchService.js`), which replies with
/// `res.json({ results, query, totalResults, executionTime, pagination })` where each entry in
/// `results` comes from `searchInCollection` as
/// `{ collection: { id, name, slug }, results: [fullMatchedDocuments], pagination: { page, limit,
/// total, totalPages } }` — full matched documents per collection, not id/score pairs, and no
/// top-level `success`/`data` envelope at all. This is the same class of generated-SDK/live-API
/// gap already documented for `customRole` on login (see `Networking/AuthGateway.swift`) — the
/// OpenAPI spec behind this endpoint just doesn't describe what the server returns. Decoding the
/// raw JSON tree by hand here, into the same `MudbaseDocument` every other gateway already uses,
/// sidesteps the wrong generated model entirely instead of building on top of it. Also documented
/// in `../web/plan/build-plan.md` "Platform issues discovered during the live smoke test" #2 —
/// this is the real substring-search mechanism (`$regex`/`$text` are hard-blocked in the
/// collection-data `filter` param, intentionally, as a DoS control).
struct SearchGateway {
    let projectId: String
    let baseURL: URL

    struct CollectionResult {
        let documents: [MudbaseDocument]
        let total: Int
    }

    /// - Parameters:
    ///   - collectionSlug: The collection's **slug**, not its `_id` — the server matches
    ///     `collections=` against `Collection.slug` (`getCollectionIds` in `searchService.js`).
    func search(collectionSlug: String, q: String, limit: Int = 50, page: Int = 1) async throws(ErrorResponse) -> CollectionResult {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/search/projects/\(projectId)/search"), resolvingAgainstBaseURL: false) else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.malformedSessionUser)
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "collections", value: collectionSlug),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "page", value: String(page)),
        ]
        guard let url = components.url else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.malformedSessionUser)
        }

        // Routed through `AccessTokenCoordinator` for the same transparent 401-refresh-and-retry
        // policy every other authenticated call in the app gets, even though this bypasses the
        // generated SDK's own request builder — `fetchJSON` reads the same bearer token
        // `MudbaseSDKBootstrap` keeps `MudbaseSDKAPIConfiguration.shared.customHeaders` in sync
        // with.
        let root = try await AccessTokenCoordinator.shared.perform { () async throws(ErrorResponse) in
            try await Self.fetchJSON(url: url)
        }

        guard let resultsArray = root["results"]?.arrayValue, let firstCollection = resultsArray.first else {
            return CollectionResult(documents: [], total: 0)
        }
        let documents = (firstCollection["results"]?.arrayValue ?? []).compactMap(MudbaseDocument.init(rawDocument:))
        let total = firstCollection["pagination"]?["total"]?.intValue ?? documents.count
        return CollectionResult(documents: documents, total: total)
    }

    /// `JSONValue` is `Sendable, Codable, Hashable` (see the SDK's `JSONValue.swift`), so this can
    /// safely cross the `perform` closure boundary as `T: Sendable` — `MudbaseDocument` itself is
    /// only built afterward, outside the actor-isolated `perform` call, matching
    /// `CollectionsGateway`'s own pattern of decoding the SDK's raw response inside `perform` and
    /// building domain objects from it after.
    private static func fetchJSON(url: URL) async throws(ErrorResponse) -> JSONValue {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let authorization = MudbaseSDKBootstrap.currentAuthorizationHeader {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ErrorResponse.error(-1, nil, nil, error)
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(statusCode) else {
            throw ErrorResponse.error(statusCode, data, response, MudbaseClientError.malformedSessionUser)
        }

        guard let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            throw ErrorResponse.error(statusCode, data, response, MudbaseClientError.malformedSessionUser)
        }
        return decoded
    }
}
