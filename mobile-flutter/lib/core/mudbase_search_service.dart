import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import 'mudbase_exception.dart';

/// Server-side keyword search (`GET /api/search/projects/:projectId/
/// search`) - the real substring-search surface for this app.
///
/// `$regex` (and `$text`'s `$search`) are hard-blocked in the collection-data
/// `filter` param's query sanitizer (`dangerousOperators` blocklist - DoS
/// risk from unanchored/attacker-supplied patterns), confirmed live against
/// this exact project by the reference web app's own build plan
/// (`web/plan/build-plan.md` point 2). This endpoint builds its own regex
/// server-side across `title`/`description`/`name`/`content`/`email` and
/// isn't subject to that client-filter sanitizer, so it - not a `filter`
/// query - is the only way to search listings by keyword. Mirrors the web
/// app's `MudbaseClient.search()` / `useSearch()`.
class MudbaseSearchService {
  const MudbaseSearchService(this._sdk, this._projectId);

  final MudbaseSdk _sdk;
  final String _projectId;

  /// Returns the raw per-collection result documents for [collectionSlug]
  /// (matched by slug, not `_id` - the same distinction the web app's
  /// `LISTINGS_COLLECTION_SLUG` constant documents). The endpoint doesn't
  /// accept structured filters alongside `q`, so category/budget filtering
  /// happens client-side over this batch (see `ListingRepository.search`
  /// and the reference web app's `HomePage.matchesFilters`).
  Future<List<Map<String, dynamic>>> search({
    required String token,
    required String collectionSlug,
    required String q,
    int limit = 50,
  }) async {
    try {
      final response = await _sdk.dio.get<dynamic>(
        '/api/search/projects/$_projectId/search',
        queryParameters: {
          'q': q,
          'collections': collectionSlug,
          'limit': limit,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) return const [];
      final results = body['results'];
      if (results is! List || results.isEmpty) return const [];
      final firstCollection = results.first;
      if (firstCollection is! Map<String, dynamic>) return const [];
      final documents = firstCollection['results'];
      if (documents is! List) return const [];
      return documents.whereType<Map<String, dynamic>>().toList(
            growable: false,
          );
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }
}
