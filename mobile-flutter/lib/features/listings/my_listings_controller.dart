import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_data_service.dart';
import '../../data/repository_providers.dart';
import '../../models/listing.dart';
import '../auth/auth_controller.dart';

final myListingsPageProvider = StateProvider<int>((ref) => 1);

class MyListingsResult {
  const MyListingsResult({
    required this.items,
    required this.pagination,
    required this.proposalCounts,
  });

  final List<Listing> items;
  final PaginationMeta pagination;
  final Map<String, int> proposalCounts;
}

/// The signed-in client's own listings, with a live proposal count per
/// listing - mirrors the web app's `MyListingsPage`, including its batched
/// (not N+1) proposal-count query.
class MyListingsController extends AsyncNotifier<MyListingsResult> {
  @override
  Future<MyListingsResult> build() async {
    final page = ref.watch(myListingsPageProvider);
    await ref.watch(authControllerProvider.future);
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null || !isObjectId(user.id)) {
      return const MyListingsResult(
        items: [],
        pagination: PaginationMeta(
          page: 1,
          limit: 0,
          total: 0,
          totalPages: 1,
          hasMore: false,
        ),
        proposalCounts: {},
      );
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final listingRepo = ref.read(listingRepositoryProvider);
    final proposalRepo = ref.read(proposalRepositoryProvider);

    final listingPage = await authNotifier.callAuthorized(
      (token) => listingRepo.browse(
        token: token,
        filter: {'clientId': user.id},
        page: page,
        limit: 10,
      ),
    );
    final listingIds = listingPage.items.map((l) => l.id).toList();
    final counts = await authNotifier.callAuthorized(
      (token) => proposalRepo.countsForListings(
        token: token,
        listingIds: listingIds,
      ),
    );
    return MyListingsResult(
      items: listingPage.items,
      pagination: listingPage.pagination,
      proposalCounts: counts,
    );
  }
}

final myListingsControllerProvider =
    AsyncNotifierProvider<MyListingsController, MyListingsResult>(
  MyListingsController.new,
);
