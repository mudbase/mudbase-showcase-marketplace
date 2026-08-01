/// Mirrors the web app's `Listing` (`web/src/types/listing.ts`) and the live
/// `listings` collection schema (`title`, `description`, `budget`,
/// `category?`, `status`, `clientId`, `clientName`).
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.budget,
    this.category,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      status: json['status'] as String? ?? ListingStatus.open,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String description;
  final double budget;
  final String? category;
  final String status;
  final String clientId;
  final String clientName;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Mirrors `LISTING_STATUSES` in `web/src/types/listing.ts`.
abstract final class ListingStatus {
  const ListingStatus._();

  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';

  static const List<String> values = [open, inProgress, completed];
}

/// Mirrors `listingStatusLabel` in `web/src/types/listing.ts`.
String listingStatusLabel(String status) {
  return switch (status) {
    ListingStatus.open => 'Open',
    ListingStatus.inProgress => 'In progress',
    ListingStatus.completed => 'Completed',
    _ => status,
  };
}
