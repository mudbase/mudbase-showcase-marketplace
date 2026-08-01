import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/rbac.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_badge.dart';
import '../auth/auth_controller.dart';
import '../messages/widgets/message_thread.dart';
import '../proposals/widgets/proposal_review_list.dart';
import '../proposals/widgets/proposal_submit_form.dart';
import 'listing_detail_controller.dart';

/// Full listing detail: description, proposal submission (freelancer),
/// proposals review + accept/reject (owning client), message thread (client
/// + accepted freelancer). Mirrors the web app's `ListingDetailPage`
/// (`app/listings/[id]/page.tsx`).
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(listingDetailControllerProvider(listingId));
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: AsyncValueView(
        value: detailAsync,
        onRetry: () =>
            ref.invalidate(listingDetailControllerProvider(listingId)),
        data: (context, state) {
          final listing = state.listing;
          if (listing == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("This listing couldn't be found."),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/browse'),
                      child: const Text('Back to listings'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isOwningClient = user != null &&
              user.isAuthenticated &&
              isClient(user.customRole) &&
              listing.clientId == user.id;
          final isFreelancerUser = user != null &&
              user.isAuthenticated &&
              isFreelancer(user.customRole);
          final canMessage = user != null &&
              user.isAuthenticated &&
              (listing.clientId == user.id ||
                  (isFreelancerUser && state.acceptedFreelancerId == user.id));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                listing.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            StatusBadge.listing(status: listing.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Posted by ${listing.clientName} · '
                          '${formatRelativeTime(listing.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(listing.description),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              formatCurrency(listing.budget),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            if (listing.category case final category?)
                              Chip(label: Text(category)),
                          ],
                        ),
                        if (isOwningClient) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                context.push('/listings/$listingId/edit'),
                            child: const Text('Edit listing'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (user != null && isFreelancerUser) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your proposal',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          if (state.ownProposal case final ownProposal?) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Your proposed rate: '
                                  '${formatCurrency(ownProposal.proposedRate)}',
                                ),
                                StatusBadge.proposal(
                                    status: ownProposal.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(ownProposal.coverLetter),
                          ] else
                            ProposalSubmitForm(
                              listingId: listingId,
                              currentUser: user,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (isOwningClient) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proposals received',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          ProposalReviewList(listingId: listingId),
                        ],
                      ),
                    ),
                  ),
                ],
                if (canMessage)
                  if (user case final currentUser) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Visible to the client and the accepted freelancer.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            MessageThread(
                              listingId: listingId,
                              currentUserId: currentUser.id,
                              currentUserName: currentUser.fullName,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                if (user == null || !user.isAuthenticated) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text(
                        'Sign in to submit a proposal or message about this listing.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
