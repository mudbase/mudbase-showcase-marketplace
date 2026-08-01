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
import 'my_listings_controller.dart';

/// The signed-in client's own listings, with a live proposal count per
/// listing - mirrors the web app's `listings/mine/page.tsx`.
class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (authState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My listings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null || !user.isAuthenticated || !isClient(user.customRole)) {
      return Scaffold(
        appBar: AppBar(title: const Text('My listings')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Sign in with a client account to view your listings.'),
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

    final resultAsync = ref.watch(myListingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Post a listing',
            onPressed: () => context.push('/listings/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(myListingsControllerProvider),
              child: AsyncValueView(
                value: resultAsync,
                onRetry: () => ref.invalidate(myListingsControllerProvider),
                data: (context, result) {
                  if (result.items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.inbox_outlined,
                          message: "You haven't posted any listings yet.",
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
                      final listing = result.items[index];
                      final count = result.proposalCounts[listing.id] ?? 0;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/listings/${listing.id}'),
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
                                        listing.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    StatusBadge.listing(status: listing.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(formatCurrency(listing.budget)),
                                    Text(
                                      '$count proposal${count == 1 ? '' : 's'}',
                                    ),
                                    Text(formatRelativeTime(listing.createdAt)),
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
                  ref.read(myListingsPageProvider.notifier).state = page,
            ),
          ),
        ],
      ),
    );
  }
}
