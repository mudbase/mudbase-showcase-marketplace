import 'package:mudbase_showcase_marketplace/core/rbac.dart';
import 'package:test/test.dart';

void main() {
  group('isAppRole', () {
    test('accepts the two known role slugs', () {
      expect(isAppRole('client'), isTrue);
      expect(isAppRole('freelancer'), isTrue);
    });

    test('rejects anything else, including null', () {
      expect(isAppRole('admin'), isFalse);
      expect(isAppRole(''), isFalse);
      expect(isAppRole(null), isFalse);
    });
  });

  group('isClient / isFreelancer', () {
    test('isClient only matches "client"', () {
      expect(isClient(AppRole.client), isTrue);
      expect(isClient(AppRole.freelancer), isFalse);
      expect(isClient(null), isFalse);
    });

    test('isFreelancer only matches "freelancer"', () {
      expect(isFreelancer(AppRole.freelancer), isTrue);
      expect(isFreelancer(AppRole.client), isFalse);
      expect(isFreelancer(null), isFalse);
    });
  });

  group('roleLabel', () {
    test('produces a human-readable label for every known role', () {
      expect(roleLabel(AppRole.client), 'Client');
      expect(roleLabel(AppRole.freelancer), 'Freelancer');
    });

    test('falls back to "Guest" for anything else, including null', () {
      expect(roleLabel(null), 'Guest');
      expect(roleLabel('admin'), 'Guest');
    });
  });
}
