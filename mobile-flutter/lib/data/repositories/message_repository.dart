import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/message.dart';

class MessageRepository {
  const MessageRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// The full thread for one listing, oldest first - mirrors the web app's
  /// `MessageThread` query (`sort: "createdAt"`).
  Future<List<Message>> forListing({
    required String token,
    required String listingId,
    int limit = 100,
  }) async {
    final result = await _dataService.list(
      EnvConfig.messagesCollectionId,
      token: token,
      filter: {'listingId': listingId},
      sort: 'createdAt',
      limit: limit,
    );
    return result.data.map(Message.fromJson).toList();
  }

  /// Client + accepted-freelancer-only (enforced by the UI - see
  /// `plan/build-plan.md` "Messaging visibility"): sends a message on a
  /// listing's thread.
  Future<Message> send({
    required String token,
    required String listingId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final doc = await _dataService.create(
      EnvConfig.messagesCollectionId,
      {
        'listingId': listingId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
      },
      token: token,
    );
    return Message.fromJson(doc);
  }
}
