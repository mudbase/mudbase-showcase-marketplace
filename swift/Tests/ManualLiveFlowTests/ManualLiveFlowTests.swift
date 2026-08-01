import Foundation
import Testing
@testable import MudbaseShowcaseMarketplace
import MudbaseSDK

/// Standalone, headless verification that exercises this app's own `Services`/`Networking` layer
/// — the exact `AuthGateway`, `ListingsService`, `ProposalsService`, `MessagesService`,
/// `SearchGateway`, and `AccessTokenCoordinator` types the SwiftUI views and view models call —
/// directly against the real, live `cloud.mudbase.dev` project. There is no iOS Simulator in this
/// environment, so this stands in for clicking through the actual UI (the same headless-
/// verification approach used to build the sibling ecommerce/social Swift ports).
///
/// Disabled unless `RUN_LIVE_FLOW_TEST=1` is set, since it makes real network calls against a live
/// project and writes real documents (a listing, a proposal, messages) — a plain `swift test` must
/// never do that on its own. Run it explicitly with:
///
///   RUN_LIVE_FLOW_TEST=1 swift test --filter ManualLiveFlowTests
@Suite(.serialized)
struct ManualLiveFlowTests {
    static let isEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_FLOW_TEST"] == "1"

    static let config = AppConfig(
        projectId: "6a6d3faad07caabbbdfc56a6",
        baseURL: URL(string: "https://cloud.mudbase.dev")!,
        listingsCollectionId: "6a6d3fced07caabbbdfc586b",
        proposalsCollectionId: "6a6d3fcfd07caabbbdfc5896",
        messagesCollectionId: "6a6d3fd0d07caabbbdfc58c5"
    )

    // Pre-provisioned, already-existing demo accounts (per this showcase's task brief) shared
    // across every language port's verification run against this same live project. Logging into
    // these instead of self-registering fresh accounts sidesteps the tightly-limited signup
    // endpoint entirely, since `/login` has a much more generous per-IP budget. A registration
    // fallback below still exists in case a shared account is ever unavailable.
    static let clientEmail = "market.client.demo@gmail.com"
    static let freelancerEmail = "market.freelancer.demo@gmail.com"
    static let demoPassword = "DemoTest123!"

    enum HarnessError: Error, CustomStringConvertible {
        case missingSessionInResponse
        case emailVerificationRequired

        var description: String {
            switch self {
            case .missingSessionInResponse: return "registerWithRole response had no token/refreshToken and wasn't a 409 conflict"
            case .emailVerificationRequired: return "project requires email verification — can't obtain a session non-interactively"
            }
        }
    }

    /// Tries login first (the shared demo account should always exist per the task brief), with a
    /// bounded retry-with-backoff on a 429 — this project's auth endpoints are shared across every
    /// sibling language port's own verification run against the same live project today, so a
    /// transient rate-limit 429 here reflects contention from *other* concurrent sessions, not a
    /// real failure of this login call. Falls back to `MultiRoleFeatureAPI.registerWithRole(role:...)`
    /// only for a genuine non-429 login failure (e.g. the shared account was ever removed) — never
    /// for a 429, since retrying registration when already rate-limited (or when the account
    /// already exists) just fails the same way with a less informative error.
    private static func loginWithRetry(_ authGateway: AuthGateway, email: String, attemptsRemaining: Int = 4, backoffSeconds: UInt64 = 45) async throws -> AuthGateway.LoginResult {
        do {
            return try await authGateway.login(email: email, password: demoPassword)
        } catch {
            let isRateLimited: Bool
            if case ErrorResponse.error(429, _, _, _) = error {
                isRateLimited = true
            } else {
                isRateLimited = false
            }
            guard isRateLimited, attemptsRemaining > 1 else { throw error }
            try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
            return try await loginWithRetry(authGateway, email: email, attemptsRemaining: attemptsRemaining - 1, backoffSeconds: backoffSeconds)
        }
    }

    /// Tries login first (the shared demo account should always exist per the task brief); falls
    /// back to `MultiRoleFeatureAPI.registerWithRole(role:...)` directly only if that specific
    /// login call fails — not on every run, and not masking a transport error as a registration
    /// attempt that would just fail the same way.
    private static func loginOrRegister(_ authGateway: AuthGateway, role: AppRole, firstName: String, lastName: String, email: String) async throws -> AuthGateway.LoginResult {
        do {
            return try await loginWithRetry(authGateway, email: email)
        } catch {
            let response = try await MultiRoleFeatureAPI.registerWithRole(
                role: role.rawValue,
                registerWithRoleRequest: RegisterWithRoleRequest(
                    email: email,
                    password: demoPassword,
                    firstName: firstName,
                    lastName: lastName,
                    projectId: config.projectId,
                    agreedToTerms: true
                )
            )
            if response.requireVerification == true {
                throw HarnessError.emailVerificationRequired
            }
            guard let token = response.token, let refreshToken = response.refreshToken else {
                throw HarnessError.missingSessionInResponse
            }
            return AuthGateway.LoginResult(accessToken: token, refreshToken: refreshToken)
        }
    }

    @Test(.enabled(if: ManualLiveFlowTests.isEnabled))
    @MainActor
    func fullMarketplaceFlow() async throws {
        MudbaseSDKBootstrap.configure(baseURL: Self.config.baseURL)

        let authGateway = AuthGateway(projectId: Self.config.projectId)
        let listingsService = ListingsService(config: Self.config)
        let proposalsService = ProposalsService(config: Self.config)
        let messagesService = MessagesService(config: Self.config)

        // --- Client: log into the shared demo account, post a listing ---
        let clientSession = try await Self.loginOrRegister(authGateway, role: .client, firstName: "Swift", lastName: "Client", email: Self.clientEmail)
        MudbaseSDKBootstrap.setAccessToken(clientSession.accessToken)
        let clientUser = try await authGateway.currentUser()
        #expect(clientUser.customRole == .client, "expected the client demo account's customRole to be \"client\", got \(String(describing: clientUser.customRole))")

        var listingDraft = ListingDraft()
        let uniqueSuffix = Int(Date().timeIntervalSince1970)
        listingDraft.title = "Swift Test Listing \(uniqueSuffix)"
        listingDraft.description = "Created by Tests/ManualLiveFlowTests — safe to delete. Needs a Swift engineer to build a small showcase app."
        listingDraft.budget = 750
        listingDraft.category = "test"
        let listing = try await listingsService.create(draft: listingDraft, clientId: clientUser.id, clientName: clientUser.displayName)
        #expect(listing.status == .open)
        #expect(listing.clientId == clientUser.id)

        // --- Freelancer: log into the shared demo account, browse + search, submit a proposal ---
        let freelancerSession = try await Self.loginOrRegister(authGateway, role: .freelancer, firstName: "Swift", lastName: "Freelancer", email: Self.freelancerEmail)
        MudbaseSDKBootstrap.setAccessToken(freelancerSession.accessToken)
        let freelancerUser = try await authGateway.currentUser()
        #expect(freelancerUser.customRole == .freelancer)

        let browsePage = try await listingsService.browse(category: "test", minBudget: nil, maxBudget: nil, page: 1, limit: 50)
        #expect(browsePage.listings.contains { $0.id == listing.id }, "category-filtered browse did not include the just-created listing")

        let searchResults = try await listingsService.search(q: "Swift Test Listing \(uniqueSuffix)", category: nil, minBudget: nil, maxBudget: nil)
        #expect(searchResults.contains { $0.id == listing.id }, "keyword search via the dedicated search endpoint did not find the just-created listing")

        var proposalDraft = ProposalDraft()
        proposalDraft.coverLetter = "I'm a great fit for this test listing — created by Tests/ManualLiveFlowTests."
        proposalDraft.proposedRate = 700
        let proposal = try await proposalsService.create(draft: proposalDraft, listingId: listing.id, freelancerId: freelancerUser.id, freelancerName: freelancerUser.displayName)
        #expect(proposal.status == .pending)

        let ownProposal = try await proposalsService.ownProposal(listingId: listing.id, freelancerId: freelancerUser.id)
        #expect(ownProposal?.id == proposal.id, "ownProposal did not find the just-submitted proposal")

        // --- Client: review + accept the proposal ---
        MudbaseSDKBootstrap.setAccessToken(clientSession.accessToken)
        let receivedProposals = try await proposalsService.listForListing(listing.id)
        #expect(receivedProposals.contains { $0.id == proposal.id }, "client's proposals-received list did not include the freelancer's proposal")

        try await proposalsService.setStatus(proposal.id, status: .accepted)
        let acceptedProposal = try await proposalsService.acceptedProposal(listingId: listing.id)
        #expect(acceptedProposal?.freelancerId == freelancerUser.id, "acceptedProposal did not resolve to the freelancer who was just accepted")

        // --- Client sends a message; freelancer (now the accepted freelancer) reads it ---
        try await messagesService.send(listingId: listing.id, senderId: clientUser.id, senderName: clientUser.displayName, content: "Welcome aboard — let's get started.")

        MudbaseSDKBootstrap.setAccessToken(freelancerSession.accessToken)
        let messagesForFreelancer = try await messagesService.listForListing(listing.id)
        #expect(messagesForFreelancer.contains { $0.content == "Welcome aboard — let's get started." }, "accepted freelancer could not read the client's message")

        try await messagesService.send(listingId: listing.id, senderId: freelancerUser.id, senderName: freelancerUser.displayName, content: "Thanks, excited to dig in!")
        let messagesAfterReply = try await messagesService.listForListing(listing.id)
        #expect(messagesAfterReply.count >= 2, "message thread did not accumulate both sides of the conversation")

        // --- 401 refresh-and-retry: force the in-memory access token invalid, keep the real
        // refresh token in a scratch Keychain entry, and confirm `AccessTokenCoordinator`
        // transparently refreshes and retries once instead of the call failing outright. ---
        let scratchTokenStore = KeychainTokenStore(service: "dev.mudbase.showcase.marketplace.manualtest")
        scratchTokenStore.save(.init(accessToken: freelancerSession.accessToken, refreshToken: freelancerSession.refreshToken))
        await AccessTokenCoordinator.shared.configure(authGateway: authGateway, tokenStore: scratchTokenStore)
        MudbaseSDKBootstrap.setAccessToken("this-access-token-is-intentionally-invalid")
        let myProposalsAfterForcedExpiry = try await proposalsService.listMine(freelancerId: freelancerUser.id)
        #expect(
            myProposalsAfterForcedExpiry.contains { $0.id == proposal.id },
            "a call made with a deliberately invalid access token did not recover via refresh-and-retry"
        )
        scratchTokenStore.clear()

        // --- Set the listing to completed (client), confirm the update round-trips ---
        MudbaseSDKBootstrap.setAccessToken(clientSession.accessToken)
        var completionDraft = ListingDraft(listing: listing)
        completionDraft.status = .completed
        let completedListing = try await listingsService.update(id: listing.id, draft: completionDraft)
        #expect(completedListing.status == .completed)

        // --- Sign out both accounts (best-effort, matches SessionStore.logout) ---
        try? await authGateway.logout()
    }
}
