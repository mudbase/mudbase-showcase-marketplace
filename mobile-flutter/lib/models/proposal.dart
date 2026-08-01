/// Mirrors the web app's `Proposal` (`web/src/types/proposal.ts`) and the
/// live `proposals` collection schema (`listingId`, `freelancerId`,
/// `freelancerName`, `coverLetter`, `proposedRate`, `status`).
class Proposal {
  const Proposal({
    required this.id,
    required this.listingId,
    required this.freelancerId,
    required this.freelancerName,
    required this.coverLetter,
    required this.proposedRate,
    required this.status,
    required this.createdAt,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['_id'] as String? ?? '',
      listingId: json['listingId'] as String? ?? '',
      freelancerId: json['freelancerId'] as String? ?? '',
      freelancerName: json['freelancerName'] as String? ?? '',
      coverLetter: json['coverLetter'] as String? ?? '',
      proposedRate: (json['proposedRate'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? ProposalStatus.pending,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String listingId;
  final String freelancerId;
  final String freelancerName;
  final String coverLetter;
  final double proposedRate;
  final String status;
  final DateTime createdAt;
}

/// Mirrors `PROPOSAL_STATUSES` in `web/src/types/proposal.ts`.
abstract final class ProposalStatus {
  const ProposalStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
}

/// Mirrors `proposalStatusLabel` in `web/src/types/proposal.ts`.
String proposalStatusLabel(String status) {
  return switch (status) {
    ProposalStatus.pending => 'Pending',
    ProposalStatus.accepted => 'Accepted',
    ProposalStatus.rejected => 'Rejected',
    _ => status,
  };
}
