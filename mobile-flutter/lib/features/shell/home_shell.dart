import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The bottom navigation shell (Browse / Account), one branch per tab via
/// `StatefulShellRoute.indexedStack` - each tab keeps its own navigation
/// stack and scroll position when switching away and back. Role-specific
/// destinations (post a listing, my listings, my proposals) live on the
/// Account tab / are pushed on top of it, rather than being their own fixed
/// shell branches, since which of those apply changes with the signed-in
/// role (client vs freelancer vs guest) - see `AccountScreen`.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
