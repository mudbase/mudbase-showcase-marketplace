import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/proposal.dart';

class ProposalPage {
  const ProposalPage({required this.items, required this.pagination});

  final List<Proposal> items;
  final PaginationMeta pagination;
}

class ProposalRepository {
  const ProposalRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// Every proposal on one listing, newest first - the client-owner's
  /// "Proposals received" review list.
  Future<List<Proposal>> forListing({
    required String token,
    required String listingId,
    int limit = 100,
  }) async {
    final result = await _dataService.list(
      EnvConfig.proposalsCollectionId,
      token: token,
      filter: {'listingId': listingId},
      sort: '-createdAt',
      limit: limit,
    );
    return result.data.map(Proposal.fromJson).toList();
  }

  /// A freelancer's own proposal on one listing, if any - determines
  /// whether the listing detail screen shows the submission form or the
  /// freelancer's existing status.
  Future<Proposal?> ownProposal({
    required String token,
    required String listingId,
    required String freelancerId,
  }) async {
    final result = await _dataService.list(
      EnvConfig.proposalsCollectionId,
      token: token,
      filter: {'listingId': listingId, 'freelancerId': freelancerId},
      limit: 1,
    );
    if (result.data.isEmpty) return null;
    return Proposal.fromJson(result.data.first);
  }

  /// Whichever proposal (if any) has been accepted on this listing - decides
  /// who besides the client can see and use the message thread. See
  /// `plan/build-plan.md` "Messaging visibility".
  Future<String?> acceptedFreelancerId({
    required String token,
    required String listingId,
  }) async {
    final result = await _dataService.list(
      EnvConfig.proposalsCollectionId,
      token: token,
      filter: {'listingId': listingId, 'status': ProposalStatus.accepted},
      limit: 1,
      fields: const ['freelancerId'],
    );
    if (result.data.isEmpty) return null;
    return result.data.first['freelancerId'] as String?;
  }

  /// This freelancer's own proposals across every listing, newest first,
  /// paginated.
  Future<ProposalPage> mine({
    required String token,
    required String freelancerId,
    int page = 1,
    int limit = 10,
  }) async {
    final result = await _dataService.list(
      EnvConfig.proposalsCollectionId,
      token: token,
      filter: {'freelancerId': freelancerId},
      sort: '-createdAt',
      page: page,
      limit: limit,
    );
    return ProposalPage(
      items: result.data.map(Proposal.fromJson).toList(),
      pagination: result.pagination,
    );
  }

  /// Proposal counts across a batch of listing ids in one query, instead of
  /// an N+1 query per listing - mirrors the web app's `MyListingsPage`.
  Future<Map<String, int>> countsForListings({
    required String token,
    required List<String> listingIds,
  }) async {
    if (listingIds.isEmpty) return const {};
    final result = await _dataService.list(
      EnvConfig.proposalsCollectionId,
      token: token,
      filter: {
        'listingId': {r'$in': listingIds},
      },
      limit: 100,
      fields: const ['listingId'],
    );
    final counts = <String, int>{};
    for (final doc in result.data) {
      final listingId = doc['listingId'] as String?;
      if (listingId == null) continue;
      counts[listingId] = (counts[listingId] ?? 0) + 1;
    }
    return counts;
  }

  /// Freelancer-only: submits a proposal on a listing.
  Future<Proposal> create({
    required String token,
    required String listingId,
    required String freelancerId,
    required String freelancerName,
    required String coverLetter,
    required double proposedRate,
  }) async {
    final doc = await _dataService.create(
      EnvConfig.proposalsCollectionId,
      {
        'listingId': listingId,
        'freelancerId': freelancerId,
        'freelancerName': freelancerName,
        'coverLetter': coverLetter,
        'proposedRate': proposedRate,
        'status': ProposalStatus.pending,
      },
      token: token,
    );
    return Proposal.fromJson(doc);
  }

  /// Client-owner-only: accepts or rejects a proposal on one of their own
  /// listings.
  Future<Proposal> updateStatus({
    required String token,
    required String proposalId,
    required String status,
  }) async {
    final doc = await _dataService.update(
      EnvConfig.proposalsCollectionId,
      proposalId,
      {'status': status},
      token: token,
    );
    return Proposal.fromJson(doc);
  }
}
