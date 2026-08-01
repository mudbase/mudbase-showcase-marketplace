import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../core/mudbase_search_service.dart';
import '../../models/listing.dart';

/// A page of [Listing]s plus pagination metadata - mirrors the web app's
/// `ListResponse<Listing>`.
class ListingPage {
  const ListingPage({required this.items, required this.pagination});

  final List<Listing> items;
  final PaginationMeta pagination;
}

class ListingRepository {
  const ListingRepository(this._dataService, this._searchService);

  final MudbaseDataService _dataService;
  final MudbaseSearchService _searchService;

  /// Real server-side filter + pagination on category/budget (no keyword) -
  /// mirrors the web app's `HomePage` "Branch 1".
  Future<ListingPage> browse({
    required String token,
    Map<String, dynamic>? filter,
    int page = 1,
    int limit = 12,
  }) async {
    final result = await _dataService.list(
      EnvConfig.listingsCollectionId,
      token: token,
      filter: filter,
      sort: '-createdAt',
      page: page,
      limit: limit,
    );
    return ListingPage(
      items: result.data.map(Listing.fromJson).toList(),
      pagination: result.pagination,
    );
  }

  /// Server-side keyword search over `title`/`description` via the
  /// dedicated search endpoint - mirrors the web app's `HomePage` "Branch 2".
  /// The caller applies category/budget filtering and pagination
  /// client-side over this batch (see `ListingsController`), since the
  /// search endpoint doesn't accept structured filters alongside `q`.
  Future<List<Listing>> search({
    required String token,
    required String q,
    int limit = 50,
  }) async {
    final docs = await _searchService.search(
      token: token,
      collectionSlug: EnvConfig.listingsCollectionSlug,
      q: q,
      limit: limit,
    );
    return docs.map(Listing.fromJson).toList();
  }

  /// A lightweight, unfiltered sample used only to populate the category
  /// filter's options - avoids a dedicated "distinct categories" endpoint
  /// that Mudbase's data API doesn't expose. Mirrors the web app's
  /// `categorySample` query.
  Future<List<String>> distinctCategorySample({
    required String token,
    int limit = 100,
  }) async {
    final result = await _dataService.list(
      EnvConfig.listingsCollectionId,
      token: token,
      limit: limit,
      fields: const ['category'],
    );
    final categories = <String>{};
    for (final doc in result.data) {
      final category = doc['category'] as String?;
      if (category != null && category.isNotEmpty) categories.add(category);
    }
    final sorted = categories.toList()..sort();
    return sorted;
  }

  Future<Listing?> getById({required String token, required String id}) async {
    final doc = await _dataService.getById(
      EnvConfig.listingsCollectionId,
      id,
      token: token,
    );
    return doc == null ? null : Listing.fromJson(doc);
  }

  /// Client-only: posts a new listing. `clientId`/`clientName` are set from
  /// the current session, never client-editable after creation.
  Future<Listing> create({
    required String token,
    required String title,
    required String description,
    required double budget,
    String? category,
    required String clientId,
    required String clientName,
  }) async {
    final doc = await _dataService.create(
      EnvConfig.listingsCollectionId,
      {
        'title': title,
        'description': description,
        'budget': budget,
        if (category != null && category.isNotEmpty) 'category': category,
        'status': ListingStatus.open,
        'clientId': clientId,
        'clientName': clientName,
      },
      token: token,
    );
    return Listing.fromJson(doc);
  }

  /// Client-owner-only: edits title/description/budget/category/status.
  Future<Listing> update({
    required String token,
    required String id,
    required String title,
    required String description,
    required double budget,
    String? category,
    required String status,
  }) async {
    final doc = await _dataService.update(
      EnvConfig.listingsCollectionId,
      id,
      {
        'title': title,
        'description': description,
        'budget': budget,
        if (category != null && category.isNotEmpty) 'category': category,
        'status': status,
      },
      token: token,
    );
    return Listing.fromJson(doc);
  }
}
