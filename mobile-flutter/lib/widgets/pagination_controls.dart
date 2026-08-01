import 'package:flutter/material.dart';

import '../core/mudbase_data_service.dart';

/// Page indicator + prev/next buttons - mirrors the web app's
/// `PaginationControls.tsx`.
class PaginationControls extends StatelessWidget {
  const PaginationControls({
    required this.pagination,
    required this.onPageChange,
    super.key,
  });

  final PaginationMeta? pagination;
  final ValueChanged<int> onPageChange;

  @override
  Widget build(BuildContext context) {
    final meta = pagination;
    if (meta == null || meta.totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${meta.page} of ${meta.totalPages} · ${meta.total} total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed:
                    meta.page > 1 ? () => onPageChange(meta.page - 1) : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed:
                    meta.hasMore ? () => onPageChange(meta.page + 1) : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
