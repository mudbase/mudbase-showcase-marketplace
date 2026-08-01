import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/service_providers.dart';
import 'repositories/listing_repository.dart';
import 'repositories/message_repository.dart';
import 'repositories/proposal_repository.dart';

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository(
    ref.watch(mudbaseDataServiceProvider),
    ref.watch(mudbaseSearchServiceProvider),
  );
});

final proposalRepositoryProvider = Provider<ProposalRepository>((ref) {
  return ProposalRepository(ref.watch(mudbaseDataServiceProvider));
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(mudbaseDataServiceProvider));
});
