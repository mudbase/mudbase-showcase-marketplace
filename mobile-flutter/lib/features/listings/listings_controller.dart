import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mudbase_data_service.dart';
import '../../data/repository_providers.dart';
import '../../models/listing.dart';
import '../auth/auth_controller.dart';

const int _pageSize = 12;

/// The browse screen's current search/filter/pagination inputs - mirrors the
/// web app's `ListingFilterValues` + its own `page` state.
class ListingsQuery {
  const ListingsQuery({
    this.search = '',
    this.category = '',
    this.minBudget = '',
    this.maxBudget = '',
    this.page = 1,
  });

  final String search;
  final String category;
  final String minBudget;
  final String maxBudget;
  final int page;

  ListingsQuery copyWith({
    String? search,
    String? category,
    String? minBudget,
    String? maxBudget,
    int? page,
  }) {
    return ListingsQuery(
      search: search ?? this.search,
      category: category ?? this.category,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      page: page ?? this.page,
    );
  }
}

final listingsQueryProvider = StateProvider<ListingsQuery>(
  (ref) => const ListingsQuery(),
);

/// A lightweight, unfiltered sample used only to populate the category
/// filter's dropdown - mirrors the web app's `categorySample` query.
final categorySampleProvider = FutureProvider<List<String>>((ref) async {
  await ref.watch(authControllerProvider.future);
  final authNotifier = ref.read(authControllerProvider.notifier);
  final repo = ref.read(listingRepositoryProvider);
  return authNotifier.callAuthorized(
    (token) => repo.distinctCategorySample(token: token),
  );
});

class ListingsResult {
  const ListingsResult({
    required this.items,
    required this.pagination,
    required this.isSearching,
  });

  final List<Listing> items;
  final PaginationMeta pagination;
  final bool isSearching;
}

/// Owns the browse screen's listing data. Rebuilds automatically whenever
/// [listingsQueryProvider] changes (Riverpod's standard `ref.watch`-inside-
/// `build()` dependency tracking) - mirrors the web app's `useDocuments`/
/// `useSearch` query-key-based refetch without needing a manual `refresh()`
/// call on every filter change.
///
/// Branches exactly like the web app's `HomePage`: a non-empty search
/// keyword uses the dedicated search endpoint (server-side `filter` can't do
/// substring search - see `MudbaseSearchService`) and applies category/
/// budget filtering + pagination client-side over the returned batch; an
/// empty keyword uses real server-side `filter` + pagination on
/// category/budget.
class ListingsController extends AsyncNotifier<ListingsResult> {
  @override
  Future<ListingsResult> build() async {
    await ref.watch(authControllerProvider.future);
    final query = ref.watch(listingsQueryProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repo = ref.read(listingRepositoryProvider);
    final trimmedSearch = query.search.trim();

    if (trimmedSearch.isEmpty) {
      final filter = <String, dynamic>{};
      if (query.category.isNotEmpty) filter['category'] = query.category;
      final min = double.tryParse(query.minBudget);
      final max = double.tryParse(query.maxBudget);
      if (min != null || max != null) {
        filter['budget'] = {
          if (min != null) r'$gte': min,
          if (max != null) r'$lte': max,
        };
      }
      final page = await authNotifier.callAuthorized(
        (token) => repo.browse(
          token: token,
          filter: filter,
          page: query.page,
          limit: _pageSize,
        ),
      );
      return ListingsResult(
        items: page.items,
        pagination: page.pagination,
        isSearching: false,
      );
    }

    final all = await authNotifier.callAuthorized(
      (token) => repo.search(token: token, q: trimmedSearch, limit: 50),
    );
    final filtered =
        all.where((listing) => _matchesFilters(listing, query)).toList();
    final totalPages =
        filtered.isEmpty ? 1 : ((filtered.length + _pageSize - 1) ~/ _pageSize);
    final page = query.page.clamp(1, totalPages);
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = start >= filtered.length
        ? const <Listing>[]
        : filtered.sublist(start, end);
    return ListingsResult(
      items: pageItems,
      pagination: PaginationMeta(
        page: page,
        limit: _pageSize,
        total: filtered.length,
        totalPages: totalPages,
        hasMore: page < totalPages,
      ),
      isSearching: true,
    );
  }

  /// Client-side application of the category/budget filters - needed for the
  /// search branch above, since the dedicated search endpoint only takes a
  /// keyword and doesn't accept additional structured filters alongside it.
  /// Mirrors the web app's `matchesFilters`.
  bool _matchesFilters(Listing listing, ListingsQuery query) {
    if (query.category.isNotEmpty && listing.category != query.category) {
      return false;
    }
    final min = double.tryParse(query.minBudget);
    final max = double.tryParse(query.maxBudget);
    if (min != null && listing.budget < min) return false;
    if (max != null && listing.budget > max) return false;
    return true;
  }
}

final listingsControllerProvider =
    AsyncNotifierProvider<ListingsController, ListingsResult>(
  ListingsController.new,
);
