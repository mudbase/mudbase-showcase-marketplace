import Foundation

/// Mirrors `../web/src/types/message.ts`'s `Message` interface.
struct Message: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let listingId: String
    let senderId: String
    let senderName: String
    let content: String
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        listingId = document.string("listingId") ?? ""
        senderId = document.string("senderId") ?? ""
        senderName = document.string("senderName") ?? ""
        content = document.string("content") ?? ""
        createdAt = document.createdAt
    }
}
