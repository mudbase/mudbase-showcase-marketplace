/// Client-side mirror of the RBAC matrix Mudbase's own collection
/// permissions already enforce server-side (see `plan/build-plan.md` and
/// the reference web app's `plan/build-plan.md` "RBAC matrix"). This exists
/// purely to hide/disable controls a role cannot use - it is NOT the
/// security boundary. A raw API call bypassing this app's UI entirely is
/// still subject to the platform's own collection permissions and this
/// app's own document-level filtering (see `plan/build-plan.md` "Known
/// limitations" for the one documented gap: document-level RBAC here is
/// enforced by this app's queries/UI, not by the platform rejecting a
/// filter for someone else's data).
library;

/// Role slugs this project's multi-role auth is configured with. Kept as
/// plain `String` constants (not a Dart `enum`) because the wire value
/// (`user.customRole`) is exactly one of these two strings already - no
/// translation layer needed between JSON and app state.
abstract final class AppRole {
  const AppRole._();

  static const String client = 'client';
  static const String freelancer = 'freelancer';
}

bool isAppRole(String? value) {
  return value == AppRole.client || value == AppRole.freelancer;
}

bool isClient(String? role) => role == AppRole.client;

bool isFreelancer(String? role) => role == AppRole.freelancer;

String roleLabel(String? role) {
  return switch (role) {
    AppRole.client => 'Client',
    AppRole.freelancer => 'Freelancer',
    _ => 'Guest',
  };
}
