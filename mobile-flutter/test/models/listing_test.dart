import 'package:mudbase_showcase_marketplace/models/listing.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        '_id': 'listing_1',
        'title': 'Build a marketing landing page',
        'description': 'A one-page marketing site with a signup form.',
        'budget': 2500,
        'category': 'Web Development',
        'status': 'open',
        'clientId': 'client_1',
        'clientName': 'Ada Lovelace',
        'createdAt': '2026-08-01T00:00:00.000Z',
        'updatedAt': '2026-08-01T00:00:00.000Z',
      };

  group('Listing.fromJson', () {
    test('parses every field from a well-formed document', () {
      final listing = Listing.fromJson(baseJson());

      expect(listing.id, 'listing_1');
      expect(listing.title, 'Build a marketing landing page');
      expect(listing.budget, 2500);
      expect(listing.category, 'Web Development');
      expect(listing.status, ListingStatus.open);
      expect(listing.clientId, 'client_1');
      expect(listing.clientName, 'Ada Lovelace');
    });

    test('treats a missing category as null (no category set)', () {
      final json = baseJson()..remove('category');
      expect(Listing.fromJson(json).category, isNull);
    });

    test('defaults status to open when absent', () {
      final json = baseJson()..remove('status');
      expect(Listing.fromJson(json).status, ListingStatus.open);
    });

    test('coerces an integer budget field to a double', () {
      final listing = Listing.fromJson(baseJson());
      expect(listing.budget, isA<double>());
    });
  });

  group('listingStatusLabel', () {
    test('produces a human-readable label for every known status', () {
      expect(listingStatusLabel(ListingStatus.open), 'Open');
      expect(listingStatusLabel(ListingStatus.inProgress), 'In progress');
      expect(listingStatusLabel(ListingStatus.completed), 'Completed');
    });

    test('falls back to the raw value for an unknown status', () {
      expect(listingStatusLabel('archived'), 'archived');
    });
  });
}
