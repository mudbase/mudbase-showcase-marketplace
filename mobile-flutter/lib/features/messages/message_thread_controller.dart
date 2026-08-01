import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/message.dart';
import '../auth/auth_controller.dart';

/// How often the thread polls for new messages while the screen is open -
/// mirrors the web app's `MessageThread.tsx` `POLL_INTERVAL_MS`. No
/// Socket.IO channel is used for this showcase (see the reference web app's
/// `plan/build-plan.md` "Stack") - polling + cache invalidation on send is
/// sufficient at this demo's scale and keeps every port of this showcase
/// simpler to mirror without a WebSocket client per language.
const Duration _pollInterval = Duration(seconds: 4);

/// One listing's message thread - client + accepted-freelancer-only,
/// enforced by the surrounding screen (see `ListingDetailScreen.canMessage`).
/// Polls on a timer while a listener is attached and cancels on dispose.
///
/// `autoDispose` is load-bearing here, not just a default: without it,
/// Riverpod would keep every listing's `MessageThreadController` instance
/// (and its live `Timer.periodic`) alive for the lifetime of the whole app
/// session, not just while its screen is on-screen - every listing detail
/// screen the user ever opens would leave a 4-second polling timer running
/// forever in the background after they navigate away.
class MessageThreadController
    extends AutoDisposeFamilyAsyncNotifier<List<Message>, String> {
  Timer? _pollTimer;

  @override
  Future<List<Message>> build(String listingId) async {
    ref.onDispose(() => _pollTimer?.cancel());
    await ref.watch(authControllerProvider.future);
    final messages = await _fetch(listingId);
    _pollTimer =
        Timer.periodic(_pollInterval, (_) => unawaited(_poll(listingId)));
    return messages;
  }

  Future<List<Message>> _fetch(String listingId) {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repo = ref.read(messageRepositoryProvider);
    return authNotifier.callAuthorized(
      (token) => repo.forListing(token: token, listingId: listingId),
    );
  }

  /// Refetches without flashing a loading spinner over an already-visible
  /// thread - a transient poll failure is silently ignored rather than
  /// surfacing an error state over content the user can already see.
  Future<void> _poll(String listingId) async {
    try {
      final messages = await _fetch(listingId);
      state = AsyncData(messages);
    } on Exception {
      // Ignored - see method doc.
    }
  }

  Future<void> send({
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repo = ref.read(messageRepositoryProvider);
    await authNotifier.callAuthorized(
      (token) => repo.send(
        token: token,
        listingId: arg,
        senderId: senderId,
        senderName: senderName,
        content: content,
      ),
    );
    final messages = await _fetch(arg);
    state = AsyncData(messages);
  }
}

final messageThreadControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MessageThreadController, List<Message>, String>(
  MessageThreadController.new,
);
