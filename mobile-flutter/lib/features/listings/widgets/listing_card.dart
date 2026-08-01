import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/listing.dart';
import '../../../widgets/status_badge.dart';

/// A single listing row in the browse list / "My listings" screen - mirrors
/// the web app's `ListingCard.tsx`.
class ListingCard extends StatelessWidget {
  const ListingCard({required this.listing, required this.onTap, super.key});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge.listing(status: listing.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                listing.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    formatCurrency(listing.budget),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (listing.category case final category?) ...[
                    Chip(
                      label: Text(category),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    formatRelativeTime(listing.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
