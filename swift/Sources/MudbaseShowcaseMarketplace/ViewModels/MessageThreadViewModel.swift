import Foundation

/// Mirrors `../web/src/components/messages/MessageThread.tsx` — polls every 4 seconds instead of
/// a realtime channel (the web reference's own deliberate simplification, documented in
/// `plan/build-plan.md`: "sufficient for the demo's scale and keeps this reference implementation
/// simpler for the other 9 ports to mirror without needing a WebSocket client per language").
@MainActor
final class MessageThreadViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published var draft = ""
    @Published private(set) var isSending = false

    private let service: MessagesService
    private let listingId: String
    private var pollTask: Task<Void, Never>?
    private static let pollIntervalNanoseconds: UInt64 = 4_000_000_000

    init(config: AppConfig, listingId: String) {
        service = MessagesService(config: config)
        self.listingId = listingId
    }

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.load(showLoadingIndicator: self.messages.isEmpty)
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func load(showLoadingIndicator: Bool) async {
        if showLoadingIndicator { isLoading = true }
        do {
            messages = try await service.listForListing(listingId)
            errorMessage = nil
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
        if showLoadingIndicator { isLoading = false }
    }

    func send(currentUser: AppUser) async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await service.send(listingId: listingId, senderId: currentUser.id, senderName: currentUser.displayName, content: content)
            messages.append(sent)
            draft = ""
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
