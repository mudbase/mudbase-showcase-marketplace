import 'package:mudbase_showcase_marketplace/models/mudbase_user.dart';
import 'package:test/test.dart';

void main() {
  group('MudbaseUser.fromJson', () {
    test('parses a real, role-carrying account', () {
      final user = MudbaseUser.fromJson({
        'id': 'user_1',
        'email': 'market.client.demo@gmail.com',
        'firstName': 'Demo',
        'lastName': 'Client',
        'customRole': 'client',
        'emailVerified': true,
        'isAnonymous': false,
      });

      expect(user.id, 'user_1');
      expect(user.customRole, 'client');
      expect(user.isAnonymous, isFalse);
      expect(user.isAuthenticated, isTrue);
    });

    test('parses an anonymous guest session', () {
      final user = MudbaseUser.fromJson({
        'id': 'guest_1',
        'email': '',
        'firstName': '',
        'lastName': '',
        'customRole': null,
        'emailVerified': false,
        'isAnonymous': true,
      });

      expect(user.isAnonymous, isTrue);
      expect(user.customRole, isNull);
      expect(user.isAuthenticated, isFalse);
    });

    test('a non-anonymous account with no customRole is not authenticated', () {
      // Defense-in-depth: this shouldn't happen against a real signup/login
      // response, but isAuthenticated must never be true without a role.
      final user = MudbaseUser.fromJson({
        'id': 'user_2',
        'email': 'edge@example.com',
        'isAnonymous': false,
      });

      expect(user.isAuthenticated, isFalse);
    });

    test('falls back to _id when id is absent', () {
      final user = MudbaseUser.fromJson({'_id': 'fallback_id'});
      expect(user.id, 'fallback_id');
    });
  });

  group('fullName', () {
    test('joins first and last name', () {
      final user = MudbaseUser.fromJson({
        'id': 'u1',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'email': 'ada@example.com',
      });
      expect(user.fullName, 'Ada Lovelace');
    });

    test('falls back to email when both names are empty', () {
      final user = MudbaseUser.fromJson({
        'id': 'u1',
        'firstName': '',
        'lastName': '',
        'email': 'ada@example.com',
      });
      expect(user.fullName, 'ada@example.com');
    });
  });
}
