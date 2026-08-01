import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/proposal.dart';
import '../auth/auth_controller.dart';
import '../listings/listing_detail_controller.dart';

/// The client-owner's "Proposals received" review list for one listing -
/// mirrors the web app's `ProposalList.tsx`. Separate from
/// [ListingDetailController] because it has its own accept/reject mutations
/// and its own loading state, independent of the surrounding listing detail
/// screen - mirrors the web app's own separate `useDocuments`/
/// `useUpdateDocument` hooks for this section.
/// `autoDispose` for the same reason as `ListingDetailController` - this
/// list is scoped to one listing's detail screen and shouldn't outlive it.
class ProposalReviewController
    extends AutoDisposeFamilyAsyncNotifier<List<Proposal>, String> {
  @override
  Future<List<Proposal>> build(String listingId) async {
    await ref.watch(authControllerProvider.future);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repo = ref.read(proposalRepositoryProvider);
    return authNotifier.callAuthorized(
      (token) => repo.forListing(token: token, listingId: listingId),
    );
  }

  /// Accepts or rejects a proposal, then refreshes this list and the
  /// surrounding listing detail (whose `acceptedFreelancerId` - and thus
  /// message-thread visibility - depends on this write).
  Future<void> setStatus({
    required String proposalId,
    required String status,
  }) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repo = ref.read(proposalRepositoryProvider);
    await authNotifier.callAuthorized(
      (token) => repo.updateStatus(
        token: token,
        proposalId: proposalId,
        status: status,
      ),
    );
    ref.invalidateSelf();
    ref.invalidate(listingDetailControllerProvider(arg));
  }
}

final proposalReviewControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ProposalReviewController, List<Proposal>, String>(
  ProposalReviewController.new,
);
