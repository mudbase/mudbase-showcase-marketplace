/// Mirrors the web app's `Message` (`web/src/types/message.ts`) and the live
/// `messages` collection schema (`listingId`, `senderId`, `senderName`,
/// `content`).
class Message {
  const Message({
    required this.id,
    required this.listingId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] as String? ?? '',
      listingId: json['listingId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String listingId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
}
