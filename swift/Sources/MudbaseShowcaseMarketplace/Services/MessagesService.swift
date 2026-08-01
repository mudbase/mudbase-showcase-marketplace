import Foundation
import MudbaseSDK

/// Message reads/writes against the `messages` collection. Mirrors
/// `../web/src/components/messages/MessageThread.tsx` — no Socket.IO/realtime channel is used
/// (matching the web reference's deliberate simplicity), `MessageThreadViewModel` polls this
/// service every 4 seconds instead, same interval as the web app's `refetchInterval`.
struct MessagesService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.messagesCollectionId)
    }

    func listForListing(_ listingId: String, limit: Int = 100) async throws -> [Message] {
        guard Formatting.isObjectId(listingId) else { return [] }
        let result = try await gateway.list(filter: ["listingId": .string(listingId)], sort: "createdAt", limit: limit)
        return result.documents.map(Message.init(document:))
    }

    @discardableResult
    func send(listingId: String, senderId: String, senderName: String, content: String) async throws -> Message {
        let fields: [String: JSONValue?] = [
            "listingId": .string(listingId),
            "senderId": .string(senderId),
            "senderName": .string(senderName),
            "content": .string(content),
        ]
        return Message(document: try await gateway.create(fields: fields))
    }
}
