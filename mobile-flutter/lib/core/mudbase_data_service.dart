import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import 'mudbase_exception.dart';

/// Pagination metadata, mirrors the web app's `PaginationMeta`
/// (`web/src/lib/mudbase.ts`).
class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;
}

/// A page of raw documents plus its [PaginationMeta] - mirrors the web
/// app's `ListResponse<T>`.
class PagedDocuments {
  const PagedDocuments({required this.data, required this.pagination});

  final List<Map<String, dynamic>> data;
  final PaginationMeta pagination;
}

/// Generic Collections CRUD (`/api/data/projects/:projectId/collections/
/// :collectionId/data`) for the `listings`/`proposals`/`messages`
/// collections.
///
/// Bypasses the generated `DataApi` wrapper for the same reason as
/// [AuthService][auth_service.dart] (see that file's header): `DataApi
/// .listData`'s typed response only declares `_id`/`createdAt`/`updatedAt` -
/// every field this app actually reads (`title`, `budget`, `clientId`,
/// `coverLetter`, `content`, ...) would be silently dropped from a list
/// read. Ported from the sibling social/ecommerce/kanban Flutter apps'
/// `core/mudbase_data_service.dart`, extended here with real pagination
/// metadata (this app's browse/my-listings/my-proposals screens need
/// page/total/hasMore, unlike the kanban app's single-board read-everything
/// model) and an optional `fields` projection (used for the batched
/// proposal-count / listing-title lookups - see the listings/proposals
/// repositories).
class MudbaseDataService {
  const MudbaseDataService(this._sdk, this._projectId);

  final MudbaseSdk _sdk;
  final String _projectId;

  String _basePath(String collectionId, [String? documentId]) {
    final base =
        '/api/data/projects/$_projectId/collections/$collectionId/data';
    return documentId == null ? base : '$base/$documentId';
  }

  Options _authOptions(String token, {String? contentType}) {
    return Options(
      contentType: contentType,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PagedDocuments> list(
    String collectionId, {
    required String token,
    Map<String, dynamic>? filter,
    String? sort,
    int page = 1,
    int limit = 20,
    List<String>? fields,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (sort != null) 'sort': sort,
      if (filter != null && filter.isNotEmpty) 'filter': jsonEncode(filter),
      if (fields != null && fields.isNotEmpty) 'fields': fields.join(','),
    };
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId),
        queryParameters: query,
        options: _authOptions(token),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return const PagedDocuments(
          data: [],
          pagination: PaginationMeta(
            page: 1,
            limit: 0,
            total: 0,
            totalPages: 1,
            hasMore: false,
          ),
        );
      }
      final items = body['data'];
      final docs = items is List
          ? items.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      final paginationJson = body['pagination'];
      final pagination = paginationJson is Map<String, dynamic>
          ? PaginationMeta.fromJson(paginationJson)
          : PaginationMeta(
              page: page,
              limit: limit,
              total: docs.length,
              totalPages: 1,
              hasMore: false,
            );
      return PagedDocuments(data: docs, pagination: pagination);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>?> getById(
    String collectionId,
    String documentId, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId, documentId),
        options: _authOptions(token),
      );
      return _unwrapDocument(response);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> create(
    String collectionId,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        _basePath(collectionId),
        data: body,
        options: _authOptions(token, contentType: 'application/json'),
      );
      final document = _unwrapDocument(response);
      if (document == null) {
        throw const MudbaseException(
          'The server did not return the created document.',
          0,
        );
      }
      return document;
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> update(
    String collectionId,
    String documentId,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.patch<dynamic>(
        _basePath(collectionId, documentId),
        data: body,
        options: _authOptions(token, contentType: 'application/json'),
      );
      final document = _unwrapDocument(response);
      if (document == null) {
        throw const MudbaseException(
          'The server did not return the updated document.',
          0,
        );
      }
      return document;
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Map<String, dynamic>? _unwrapDocument(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    final data = body['data'];
    return data is Map<String, dynamic> ? data : null;
  }
}
