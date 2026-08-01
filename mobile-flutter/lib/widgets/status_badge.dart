import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../models/proposal.dart';

/// A colored status pill - one shared widget for both listing status
/// (`open`/`in_progress`/`completed`) and proposal status
/// (`pending`/`accepted`/`rejected`), mirroring the semantic colors the web
/// app's `<Badge variant=...>` uses in `ListingCard.tsx` /
/// `ProposalStatusBadge.tsx`.
class StatusBadge extends StatelessWidget {
  const StatusBadge.listing({required String status, super.key})
      : _label = null,
        _status = status,
        _kind = _StatusKind.listing;

  const StatusBadge.proposal({required String status, super.key})
      : _label = null,
        _status = status,
        _kind = _StatusKind.proposal;

  final String _status;
  final String? _label;
  final _StatusKind _kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (_kind) {
      _StatusKind.listing => switch (_status) {
          ListingStatus.open => (
              colorScheme.tertiaryContainer,
              colorScheme.onTertiaryContainer,
            ),
          ListingStatus.inProgress => (
              colorScheme.secondaryContainer,
              colorScheme.onSecondaryContainer,
            ),
          _ => (
              colorScheme.surfaceContainerHighest,
              colorScheme.onSurfaceVariant,
            ),
        },
      _StatusKind.proposal => switch (_status) {
          ProposalStatus.accepted => (
              colorScheme.tertiaryContainer,
              colorScheme.onTertiaryContainer,
            ),
          ProposalStatus.rejected => (
              colorScheme.errorContainer,
              colorScheme.onErrorContainer,
            ),
          _ => (
              colorScheme.secondaryContainer,
              colorScheme.onSecondaryContainer,
            ),
        },
    };
    final label = _label ??
        (_kind == _StatusKind.listing
            ? listingStatusLabel(_status)
            : proposalStatusLabel(_status));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _StatusKind { listing, proposal }
