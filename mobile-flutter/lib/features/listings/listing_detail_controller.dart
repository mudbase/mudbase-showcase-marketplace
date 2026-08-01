import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rbac.dart';
import '../../data/repository_providers.dart';
import '../../models/listing.dart';
import '../../models/proposal.dart';
import '../auth/auth_controller.dart';

/// Everything a listing's detail screen needs in one snapshot - mirrors the
/// web app's `ListingDetailPage`, which independently queries the listing,
/// the freelancer's own proposal (if any), and whichever proposal has been
/// accepted (to decide message-thread visibility), then derives
/// `isOwningClient`/`canMessage` from them.
class ListingDetailState {
  const ListingDetailState({
    required this.listing,
    required this.ownProposal,
    required this.acceptedFreelancerId,
  });

  /// `null` means the listing id didn't resolve to a document (deleted, or
  /// a bad id) - the screen shows a "not found" message rather than an
  /// error state for this case.
  final Listing? listing;

  /// The current user's own proposal on this listing, if they are a
  /// freelancer and have submitted one.
  final Proposal? ownProposal;

  /// The freelancerId of whichever proposal (if any) has been accepted on
  /// this listing - decides who besides the client can see/use the message
  /// thread. See `plan/build-plan.md` "Messaging visibility".
  final String? acceptedFreelancerId;
}

/// `autoDispose` so a listing's detail state (and the `ProposalReviewList`/
/// `MessageThread` state it indirectly keeps alive via `ref.watch`) doesn't
/// linger in memory for the whole app session once the user navigates away
/// from that listing - each listing detail screen is independent and
/// short-lived, not shared/global state.
class ListingDetailController
    extends AutoDisposeFamilyAsyncNotifier<ListingDetailState, String> {
  @override
  Future<ListingDetailState> build(String listingId) async {
    await ref.watch(authControllerProvider.future);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final user = ref.read(authControllerProvider).valueOrNull;
    final listingRepo = ref.read(listingRepositoryProvider);
    final proposalRepo = ref.read(proposalRepositoryProvider);

    final listing = await authNotifier.callAuthorized(
      (token) => listingRepo.getById(token: token, id: listingId),
    );
    if (listing == null) {
      return const ListingDetailState(
        listing: null,
        ownProposal: null,
        acceptedFreelancerId: null,
      );
    }

    final isFreelancerUser =
        user != null && user.isAuthenticated && isFreelancer(user.customRole);
    final ownProposal = isFreelancerUser
        ? await authNotifier.callAuthorized(
            (token) => proposalRepo.ownProposal(
              token: token,
              listingId: listingId,
              freelancerId: user.id,
            ),
          )
        : null;

    final acceptedFreelancerId = (user != null && user.isAuthenticated)
        ? await authNotifier.callAuthorized(
            (token) => proposalRepo.acceptedFreelancerId(
              token: token,
              listingId: listingId,
            ),
          )
        : null;

    return ListingDetailState(
      listing: listing,
      ownProposal: ownProposal,
      acceptedFreelancerId: acceptedFreelancerId,
    );
  }
}

final listingDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ListingDetailController, ListingDetailState, String>(
  ListingDetailController.new,
);
