import 'package:mudbase_showcase_marketplace/models/message.dart';
import 'package:test/test.dart';

void main() {
  group('Message.fromJson', () {
    test('parses every field from a well-formed document', () {
      final message = Message.fromJson({
        '_id': 'message_1',
        'listingId': '6a6d3fced07caabbbdfc586b',
        'senderId': 'client_1',
        'senderName': 'Ada Lovelace',
        'content': 'Looking forward to working together!',
        'createdAt': '2026-08-01T00:00:00.000Z',
      });

      expect(message.id, 'message_1');
      expect(message.listingId, '6a6d3fced07caabbbdfc586b');
      expect(message.senderId, 'client_1');
      expect(message.senderName, 'Ada Lovelace');
      expect(message.content, 'Looking forward to working together!');
    });

    test('defaults missing string fields to empty strings', () {
      final message = Message.fromJson({'_id': 'message_2'});
      expect(message.senderName, '');
      expect(message.content, '');
    });
  });
}
