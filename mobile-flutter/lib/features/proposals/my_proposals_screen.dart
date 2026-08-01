import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/rbac.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_controls.dart';
import '../../widgets/status_badge.dart';
import '../auth/auth_controller.dart';
import 'my_proposals_controller.dart';

/// The signed-in freelancer's own proposals across every listing - mirrors
/// the web app's `proposals/page.tsx`.
class MyProposalsScreen extends ConsumerWidget {
  const MyProposalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (authState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My proposals')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null ||
        !user.isAuthenticated ||
        !isFreelancer(user.customRole)) {
      return Scaffold(
        appBar: AppBar(title: const Text('My proposals')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Sign in with a freelancer account to view your proposals.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final resultAsync = ref.watch(myProposalsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My proposals')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(myProposalsControllerProvider),
              child: AsyncValueView(
                value: resultAsync,
                onRetry: () => ref.invalidate(myProposalsControllerProvider),
                data: (context, result) {
                  if (result.items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.description_outlined,
                          message: "You haven't submitted any proposals yet.",
                          action: OutlinedButton(
                            onPressed: () => context.go('/browse'),
                            child: const Text('Browse listings'),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: result.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final proposal = result.items[index];
                      final listing = result.listingsById[proposal.listingId];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () =>
                              context.push('/listings/${proposal.listingId}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        listing?.title ?? 'Listing',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    StatusBadge.proposal(
                                        status: proposal.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Your rate: '
                                      '${formatCurrency(proposal.proposedRate)}',
                                    ),
                                    Text(
                                        formatRelativeTime(proposal.createdAt)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PaginationControls(
              pagination: resultAsync.valueOrNull?.pagination,
              onPageChange: (page) =>
                  ref.read(myProposalsPageProvider.notifier).state = page,
            ),
          ),
        ],
      ),
    );
  }
}
