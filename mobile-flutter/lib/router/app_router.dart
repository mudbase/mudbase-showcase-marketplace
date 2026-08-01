import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/listings/listing_detail_screen.dart';
import '../features/listings/listing_form_screen.dart';
import '../features/listings/listings_screen.dart';
import '../features/listings/my_listings_screen.dart';
import '../features/proposals/my_proposals_screen.dart';
import '../features/shell/home_shell.dart';

/// Routes that require a real, role-carrying account (not just the
/// always-present anonymous browsing session) - mirrors each of the web
/// app's own per-page `isAuthenticated` guards
/// (`listings/new`, `listings/mine`, `proposals`, and the edit route).
bool _requiresAuth(String location) {
  return location == '/listings/new' ||
      location == '/listings/mine' ||
      location == '/proposals/mine' ||
      (location.startsWith('/listings/') && location.endsWith('/edit'));
}

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// `refreshListenable` - go_router only re-evaluates `redirect` on
/// navigation or when this notifies, so a sign-in/sign-out that happens
/// without a navigation event (e.g. the splash-screen session bootstrap
/// resolving) still re-runs the redirect logic below.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/browse',
                  builder: (context, state) => const ListingsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/listings/new',
        builder: (context, state) =>
            const ListingFormScreen(mode: ListingFormMode.create),
      ),
      GoRoute(
        path: '/listings/mine',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/proposals/mine',
        builder: (context, state) => const MyProposalsScreen(),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (context, state) => ListingDetailScreen(
          listingId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => ListingFormScreen(
              mode: ListingFormMode.edit,
              listingId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Page not found'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/browse'),
              child: const Text('Go to listings'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// This app always has a session (guest/anonymous, or a real account - see
/// `AuthController`), so unlike the sibling kanban port's redirect (which
/// sends every non-`/login` route to `/login` while signed out), guest
/// browsing is allowed everywhere except the explicitly role-gated routes in
/// [_requiresAuth] - mirrors the web app's own per-page guards rather than
/// a single blanket auth wall.
String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  final location = state.matchedLocation;
  final isAuthRoute = location == '/login' || location == '/register';

  if (authState.isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final user = authState.valueOrNull;
  if (user == null) {
    // Session bootstrap failed entirely (e.g. no connectivity on cold
    // start) - only `/login` is reachable so the user has a manual retry
    // path (a login attempt re-runs the same auth flow).
    return isAuthRoute ? null : '/login';
  }

  if (isAuthRoute && user.isAuthenticated) return '/browse';
  if (location == '/splash') return '/browse';
  if (_requiresAuth(location) && !user.isAuthenticated) return '/login';

  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
