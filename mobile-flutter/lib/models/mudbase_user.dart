/// The authenticated (or anonymous guest) end-user. Parsed from raw JSON
/// rather than the bundled Dart SDK's generated `User`/
/// `LoginLocalUser200ResponseUser` models - those only type `id`/`email`/
/// `firstName`/`lastName`/`role`/`emailVerified` and silently drop
/// `customRole`/`isAnonymous` on deserialization (confirmed by reading the
/// generated model/serializer source under `mudbase-sdk/dart/lib/src/model/`,
/// same finding the sibling social/ecommerce/kanban Flutter apps document).
/// `customRole` is exactly this app's `client`/`freelancer` role slug - see
/// `core/rbac.dart`.
class MudbaseUser {
  const MudbaseUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.customRole,
    required this.emailVerified,
    required this.isAnonymous,
  });

  factory MudbaseUser.fromJson(Map<String, dynamic> json) {
    return MudbaseUser(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      customRole: json['customRole'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? customRole;
  final bool emailVerified;
  final bool isAnonymous;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  /// A real, role-carrying account - distinct from the always-present
  /// anonymous guest session established so the listings feed can read
  /// without forcing signup. Mirrors the web app's `useAuth().isAuthenticated`
  /// exactly: `!!user && user.isAnonymous !== true && !!role`.
  bool get isAuthenticated => !isAnonymous && customRole != null;
}
