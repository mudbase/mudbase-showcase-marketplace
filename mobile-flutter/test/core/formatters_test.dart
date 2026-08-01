import 'package:mudbase_showcase_marketplace/core/formatters.dart';
import 'package:test/test.dart';

void main() {
  group('formatRelativeTime', () {
    test('reports a timestamp under 5 seconds ago as "just now"', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 2))),
        'just now',
      );
    });

    test('reports seconds ago between 5s and 60s', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30))),
        '30s',
      );
    });

    test('reports minutes ago', () {
      final now = DateTime.now();
      expect(
          formatRelativeTime(now.subtract(const Duration(minutes: 5))), '5m');
    });

    test('reports hours ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(hours: 3))), '3h');
    });

    test('reports days ago for anything under a week', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(days: 4))), '4d');
    });

    test('falls back to a medium date once older than a week', () {
      final now = DateTime.now();
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      final formatted = formatRelativeTime(eightDaysAgo);
      expect(formatted, isNot(contains('d')));
      expect(formatted.length, greaterThan(4));
    });
  });

  group('formatCurrency', () {
    test('formats whole dollars with no decimal places', () {
      expect(formatCurrency(2500), r'$2,500');
    });

    test('rounds a fractional amount', () {
      expect(formatCurrency(99.6), r'$100');
    });

    test('formats zero', () {
      expect(formatCurrency(0), r'$0');
    });
  });

  group('initials', () {
    test('takes the first letter of the first and last word', () {
      expect(initials('Ada Lovelace'), 'AL');
    });

    test('handles a single-word name', () {
      expect(initials('Cher'), 'C');
    });

    test('collapses extra internal whitespace', () {
      expect(initials('  Grace   Hopper  '), 'GH');
    });

    test('returns "?" for an empty or whitespace-only name', () {
      expect(initials(''), '?');
      expect(initials('   '), '?');
    });
  });

  group('isObjectId', () {
    test('accepts a well-formed 24-hex-char id', () {
      expect(isObjectId('6a6d3fced07caabbbdfc586b'), isTrue);
    });

    test('accepts uppercase hex characters', () {
      expect(isObjectId('6A6D3FCED07CAABBBDFC586B'), isTrue);
    });

    test('rejects null', () {
      expect(isObjectId(null), isFalse);
    });

    test('rejects a non-hex slug', () {
      expect(isObjectId('main-listing'), isFalse);
    });

    test('rejects the wrong length', () {
      expect(isObjectId('6a6d3fced07caabbbdfc58'), isFalse);
      expect(isObjectId('6a6d3fced07caabbbdfc586b00'), isFalse);
    });
  });
}
