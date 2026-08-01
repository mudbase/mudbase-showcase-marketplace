import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/mudbase_exception.dart';
import '../../core/secure_token_storage.dart';
import '../../core/service_providers.dart';
import '../../models/mudbase_user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, MudbaseUser?>(AuthController.new);

/// Owns the current session: bootstraps it from secure storage on cold
/// start (restoring a real session if one is stored, otherwise establishing
/// a guest/anonymous session so the public listings feed can read without
/// forcing signup - mirrors the reference web app's `MudbaseProvider`), and
/// drives login/register/logout.
///
/// `state.valueOrNull` is never `null` once bootstrapped (there is always at
/// least an anonymous session) - screens gate write actions on
/// `user.isAuthenticated` (a real, role-carrying account), not on
/// `state.valueOrNull == null`. This is the one deliberate divergence from
/// this app's own `AppRole`-gated sibling ports (kanban/social/ecommerce),
/// which have no anonymous session at all - this app's own web reference
/// explicitly documents guest browsing as a feature, not an oversight (see
/// `plan/build-plan.md` "Auth flow").
///
/// The access token itself is intentionally kept out of Riverpod state (it
/// would have no UI reason to trigger a rebuild). It lives in a private
/// field and in [SecureTokenStorage]; repositories read it via
/// [callAuthorized]. Ported from the sibling social/ecommerce/kanban Flutter
/// apps' `features/auth/auth_controller.dart`.
class AuthController extends AsyncNotifier<MudbaseUser?> {
  String? _token;
  String? _refreshToken;

  // Refresh tokens rotate on every use (single-use, platform-enforced) - if
  // two calls both hit a 401 at once, only the first refresh call can
  // succeed since the second would present an already-rotated-away token.
  // This lets concurrent callers await the same in-flight refresh instead of
  // racing each other into failure. Mirrors the web app's `refreshInFlight`.
  Future<String?>? _refreshInFlight;

  // Guards against two concurrent `callAuthorized` calls that both fail
  // refresh at the same time each independently clearing storage, logging
  // in anonymously again, and racing to overwrite `_token`/`state` - same
  // dedup shape as `_refreshInFlight` above, just for the fallback path.
  Future<void>? _fallbackInFlight;

  AuthService get _authService => ref.read(authServiceProvider);
  SecureTokenStorage get _tokenStorage => ref.read(secureTokenStorageProvider);

  @override
  Future<MudbaseUser?> build() async {
    final storedToken = await _tokenStorage.readToken();
    if (storedToken == null) {
      return _establishAnonymousSession();
    }
    try {
      final json = await _authService.getSession(storedToken);
      final userJson = json['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        await _tokenStorage.clear();
        return _establishAnonymousSession();
      }
      _token = storedToken;
      _refreshToken = await _tokenStorage.readRefreshToken();
      return MudbaseUser.fromJson(userJson);
    } on Exception {
      // An expired/revoked stored token resolves to a fresh anonymous
      // session rather than a hard startup crash - browsing must always
      // work, even when the previously-signed-in session is gone.
      await _tokenStorage.clear();
      return _establishAnonymousSession();
    }
  }

  Future<MudbaseUser> _establishAnonymousSession() async {
    final json = await _authService.loginAnonymous();
    final token = json['token'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw const MudbaseException(
        'Could not establish a browsing session. Please try again.',
        0,
      );
    }
    _token = token;
    _refreshToken = json['refreshToken'] as String?;
    await _tokenStorage.saveSession(token: token, refreshToken: _refreshToken);
    return MudbaseUser.fromJson(userJson);
  }

  String requireToken() {
    final token = _token;
    if (token == null) {
      throw StateError('requireToken() called with no active session.');
    }
    return token;
  }

  /// Runs [action] with the current access token and, if it fails because
  /// the token expired or was revoked (a 401 from any Mudbase endpoint),
  /// transparently refreshes the session via the stored refresh token and
  /// retries [action] exactly once with the new token. Mirrors the web
  /// app's `MudbaseClient.request`'s `retriedAfterRefresh` handling
  /// (`web/src/lib/mudbase.ts`).
  ///
  /// If the refresh itself fails, the session falls back to a fresh
  /// anonymous one (never a hard-stuck signed-out screen - see the class
  /// doc) and the *original* 401 is rethrown, so the caller's existing
  /// error handling still fires.
  Future<T> callAuthorized<T>(Future<T> Function(String token) action) async {
    final token = requireToken();
    try {
      return await action(token);
    } on MudbaseException catch (error) {
      if (error.statusCode != 401) rethrow;
      final refreshed = await _refreshAccessToken();
      if (refreshed == null) {
        await _fallBackToAnonymous();
        rethrow;
      }
      return action(refreshed);
    }
  }

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;
    try {
      final json = await _authService.refreshSession(refreshToken);
      final newToken = json['token'] as String?;
      if (newToken == null) return null;
      final newRefreshToken = json['refreshToken'] as String?;
      _token = newToken;
      _refreshToken = newRefreshToken;
      await _tokenStorage.saveSession(
        token: newToken,
        refreshToken: newRefreshToken,
      );
      return newToken;
    } on Exception {
      // Refresh token expired/revoked/already rotated away, or the server
      // was briefly unreachable - either way there is no new token to hand
      // back, so the caller in [callAuthorized] falls back to anonymous.
      return null;
    }
  }

  Future<void> _fallBackToAnonymous() {
    return _fallbackInFlight ??= _performFallbackToAnonymous().whenComplete(() {
      _fallbackInFlight = null;
    });
  }

  Future<void> _performFallbackToAnonymous() async {
    await _tokenStorage.clear();
    _token = null;
    _refreshToken = null;
    try {
      final user = await _establishAnonymousSession();
      state = AsyncData(user);
    } on Exception {
      state = const AsyncData(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    final json = await _authService.login(email: email, password: password);
    await _applySession(json);
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required bool agreedToTerms,
  }) async {
    final json = await _authService.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
      agreedToTerms: agreedToTerms,
    );
    await _applySession(json);
  }

  /// Signs out and immediately re-establishes a guest/anonymous session so
  /// browsing keeps working - a deliberate improvement over strictly
  /// mirroring the reference web app's `MudbaseProvider` (which only
  /// establishes the anonymous session once, on initial mount, so its own
  /// session goes fully `null` after logout until the page is reloaded). A
  /// mobile app has no equivalent "reload the page" affordance, so leaving
  /// the user on a broken guest state after signing out would be a real UX
  /// regression, not parity.
  ///
  /// Deliberately does **not** set `state = const AsyncLoading()` while the
  /// anonymous session is re-established: the router's `_AuthRefreshNotifier`
  /// (`router/app_router.dart`) re-evaluates its redirect on every auth state
  /// change and sends any non-`/splash` location to `/splash` while loading -
  /// a brief loading state here would visibly bounce the UI to the splash
  /// screen and back for what should be an in-place account refresh. The
  /// previous (signed-in) user's data simply remains on screen until the new
  /// anonymous session lands.
  Future<void> logout() async {
    final token = _token;
    if (token != null) {
      try {
        await _authService.logout(token);
      } on Exception {
        // Best-effort - AuthService.logout() already swallows a 401
        // (already revoked), and the local sign-out below must happen
        // regardless of whether the server revoke succeeds.
      }
    }
    await _tokenStorage.clear();
    _token = null;
    _refreshToken = null;
    try {
      final user = await _establishAnonymousSession();
      state = AsyncData(user);
    } on Exception catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _applySession(Map<String, dynamic> json) async {
    final token = json['token'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw const FormatException(
        'The server did not return a session for this account.',
      );
    }
    _token = token;
    _refreshToken = json['refreshToken'] as String?;
    await _tokenStorage.saveSession(token: token, refreshToken: _refreshToken);
    state = AsyncData(MudbaseUser.fromJson(userJson));
  }
}
