import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/mudbase_data_service.dart';
import '../../data/repository_providers.dart';
import '../../models/listing.dart';
import '../../models/proposal.dart';
import '../auth/auth_controller.dart';

final myProposalsPageProvider = StateProvider<int>((ref) => 1);

class MyProposalsResult {
  const MyProposalsResult({
    required this.items,
    required this.pagination,
    required this.listingsById,
  });

  final List<Proposal> items;
  final PaginationMeta pagination;
  final Map<String, Listing> listingsById;
}

/// The signed-in freelancer's own proposals across every listing, with the
/// referenced listing's title batched in one query - mirrors the web app's
/// `MyProposalsPage`.
class MyProposalsController extends AsyncNotifier<MyProposalsResult> {
  @override
  Future<MyProposalsResult> build() async {
    final page = ref.watch(myProposalsPageProvider);
    await ref.watch(authControllerProvider.future);
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null || !isObjectId(user.id)) {
      return const MyProposalsResult(
        items: [],
        pagination: PaginationMeta(
          page: 1,
          limit: 0,
          total: 0,
          totalPages: 1,
          hasMore: false,
        ),
        listingsById: {},
      );
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final proposalRepo = ref.read(proposalRepositoryProvider);
    final listingRepo = ref.read(listingRepositoryProvider);

    final proposalPage = await authNotifier.callAuthorized(
      (token) => proposalRepo.mine(
        token: token,
        freelancerId: user.id,
        page: page,
        limit: 10,
      ),
    );
    final listingIds = {
      for (final proposal in proposalPage.items) proposal.listingId,
    }.toList();

    final listingsById = <String, Listing>{};
    if (listingIds.isNotEmpty) {
      final listingPage = await authNotifier.callAuthorized(
        (token) => listingRepo.browse(
          token: token,
          filter: {
            '_id': {r'$in': listingIds},
          },
          limit: 100,
        ),
      );
      for (final listing in listingPage.items) {
        listingsById[listing.id] = listing;
      }
    }

    return MyProposalsResult(
      items: proposalPage.items,
      pagination: proposalPage.pagination,
      listingsById: listingsById,
    );
  }
}

final myProposalsControllerProvider =
    AsyncNotifierProvider<MyProposalsController, MyProposalsResult>(
  MyProposalsController.new,
);
