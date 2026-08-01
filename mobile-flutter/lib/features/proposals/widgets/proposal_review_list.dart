import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../models/proposal.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/status_badge.dart';
import '../proposal_review_controller.dart';

/// The client-owner's "Proposals received" review list, with accept/reject
/// actions on pending proposals - mirrors the web app's `ProposalList.tsx`.
class ProposalReviewList extends ConsumerStatefulWidget {
  const ProposalReviewList({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<ProposalReviewList> createState() => _ProposalReviewListState();
}

class _ProposalReviewListState extends ConsumerState<ProposalReviewList> {
  String? _actioningId;

  Future<void> _setStatus(String proposalId, String status) async {
    setState(() => _actioningId = proposalId);
    try {
      await ref
          .read(proposalReviewControllerProvider(widget.listingId).notifier)
          .setStatus(proposalId: proposalId, status: status);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _actioningId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(
      proposalReviewControllerProvider(widget.listingId),
    );

    return AsyncValueView<List<Proposal>>(
      value: proposalsAsync,
      onRetry: () =>
          ref.invalidate(proposalReviewControllerProvider(widget.listingId)),
      data: (context, proposals) {
        if (proposals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No proposals yet.'),
          );
        }
        return Column(
          children: [
            for (final proposal in proposals) ...[
              _ProposalTile(
                proposal: proposal,
                isActioning: _actioningId == proposal.id,
                onAccept: () =>
                    _setStatus(proposal.id, ProposalStatus.accepted),
                onReject: () =>
                    _setStatus(proposal.id, ProposalStatus.rejected),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.isActioning,
    required this.onAccept,
    required this.onReject,
  });

  final Proposal proposal;
  final bool isActioning;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.freelancerName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${formatCurrency(proposal.proposedRate)} · '
                        '${formatRelativeTime(proposal.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge.proposal(status: proposal.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(proposal.coverLetter),
            if (proposal.status == ProposalStatus.pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: isActioning ? null : onAccept,
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isActioning ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
