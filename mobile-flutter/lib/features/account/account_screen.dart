import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rbac.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/role_badge.dart';
import '../auth/auth_controller.dart';

/// Sign-in/out + role-specific navigation (post a listing / my listings /
/// my proposals) - mirrors the nav items in the web app's `Header.tsx`,
/// which this mobile port surfaces as its own tab rather than a persistent
/// top bar (there is more of it than fits an `AppBar` comfortably on
/// mobile).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final isSignedIn = user != null && user.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isSignedIn) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          InitialsAvatar(name: user.fullName, radius: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          RoleBadge(role: user.customRole),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isClient(user.customRole)) ...[
                    _AccountAction(
                      icon: Icons.add_circle_outline,
                      label: 'Post a listing',
                      onTap: () => context.push('/listings/new'),
                    ),
                    _AccountAction(
                      icon: Icons.work_outline,
                      label: 'My listings',
                      onTap: () => context.push('/listings/mine'),
                    ),
                  ],
                  if (isFreelancer(user.customRole))
                    _AccountAction(
                      icon: Icons.description_outlined,
                      label: 'My proposals',
                      onTap: () => context.push('/proposals/mine'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ] else ...[
                  Text(
                    'Sign in to post work, submit proposals, or message about a listing.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Create an account'),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Built entirely on Mudbase — no custom backend.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
