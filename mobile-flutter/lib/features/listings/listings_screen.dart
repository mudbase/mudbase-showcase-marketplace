import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pagination_controls.dart';
import 'listings_controller.dart';
import 'widgets/listing_card.dart';
import 'widgets/listing_filters_bar.dart';

/// Browse listings - search, category filter, budget range, pagination.
/// Mirrors the web app's `HomePage` (`app/page.tsx`).
class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(listingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find your next project')),
      body: Column(
        children: [
          const ListingFiltersBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(listingsControllerProvider),
              child: AsyncValueView(
                value: resultAsync,
                onRetry: () => ref.invalidate(listingsControllerProvider),
                data: (context, result) {
                  if (result.items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.work_outline,
                          message: 'No listings match your filters.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: result.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final listing = result.items[index];
                      return ListingCard(
                        listing: listing,
                        onTap: () => context.push('/listings/${listing.id}'),
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
              onPageChange: (page) {
                final current = ref.read(listingsQueryProvider);
                ref.read(listingsQueryProvider.notifier).state =
                    current.copyWith(page: page);
              },
            ),
          ),
        ],
      ),
    );
  }
}
