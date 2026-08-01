import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import 'mudbase_exception.dart';

/// Auth calls against the real Mudbase project. Ported from the sibling
/// social/ecommerce/kanban Flutter apps' `core/auth_service.dart` - same
/// reasoning, same bypass of the generated wrapper classes:
///
/// Every response model the SDK types for auth (`LoginLocalUser200Response`,
/// `User`, ...) declares `role` but not `customRole` - built_value's
/// standard JSON deserializer silently drops unknown fields rather than
/// erroring, so calling through the typed wrapper would silently lose
/// exactly the field this app gates every write on (`client`/`freelancer`).
///
/// Every request body below is a small, fixed, hand-verified JSON shape
/// (matching `web/src/lib/mudbase.ts` byte-for-byte) built as a plain
/// `Map<String, dynamic>` rather than through the SDK's generated
/// `built_value` builder classes - `dio` serializes a `Map` to a JSON body
/// on its own, and there is no generated builder at all for several of
/// these calls (`/api/auth/refresh`, `/api/auth/anonymous`, and the
/// role-specific `/api/auth/local/signup/:role`), so a single, consistent,
/// hand-built-JSON approach across every method here is simpler and no less
/// correct than mixing builder classes in for only the one or two calls
/// that happen to have one.
class AuthService {
  const AuthService(this._sdk, this._projectId);

  final MudbaseSdk _sdk;
  final String _projectId;

  /// `POST /api/auth/anonymous` - establishes a guest session so the public
  /// listings feed can read without forcing signup (same "authenticated-role
  /// read" pattern as the reference web app's `MudbaseProvider`). Returns
  /// the same `{ token, refreshToken?, user }` shape as [login]/[register].
  Future<Map<String, dynamic>> loginAnonymous() async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/anonymous',
        data: {'projectId': _projectId},
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/local/login',
        data: {'email': email, 'password': password, 'projectId': _projectId},
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// `POST /api/auth/local/signup/:role` - the signup validator explicitly
  /// rejects `role`/`customRole` inside the request body (a deliberate
  /// anti-role-injection control, confirmed in the reference web app's
  /// `MudbaseClient.register`), so the role is only ever taken from the URL
  /// path segment here, never spread into the body too.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required bool agreedToTerms,
  }) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/local/signup/$role',
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'agreedToTerms': agreedToTerms,
          'projectId': _projectId,
        },
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// `POST /api/auth/refresh` - exchanges a still-valid refresh token for a
  /// new access/refresh pair. No generated builder class exists for this
  /// request, so the body is constructed by hand, same as the sibling
  /// ports.
  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// `GET /api/auth/session` - both org- and project-scoped bearer tokens
  /// are accepted by this endpoint, so it works the same right after a
  /// local login as it does on cold-start session restore.
  Future<Map<String, dynamic>> getSession(String token) async {
    try {
      final response = await _sdk.dio.get<dynamic>(
        '/api/auth/session',
        queryParameters: {'projectId': _projectId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<void> logout(String token) async {
    try {
      await _sdk.dio.post<dynamic>(
        '/api/auth/logout',
        data: {'projectId': _projectId},
        options: Options(
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (error) {
      // Logout is a best-effort server-side revoke - the client clears its
      // own token regardless (see AuthController.logout), so a failed
      // revoke call must not block the local sign-out.
      if (error.response?.statusCode == 401) return;
      throw MudbaseException.fromDioException(error);
    }
  }

  Map<String, dynamic> _asJsonMap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw const MudbaseException(
      'Unexpected response shape from the server.',
      0,
    );
  }
}
