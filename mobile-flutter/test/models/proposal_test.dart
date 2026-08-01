import 'package:mudbase_showcase_marketplace/models/proposal.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        '_id': 'proposal_1',
        'listingId': '6a6d3fced07caabbbdfc586b',
        'freelancerId': 'freelancer_1',
        'freelancerName': 'Grace Hopper',
        'coverLetter': "I'm a great fit for this project.",
        'proposedRate': 1500,
        'status': 'pending',
        'createdAt': '2026-08-01T00:00:00.000Z',
      };

  group('Proposal.fromJson', () {
    test('parses every field from a well-formed document', () {
      final proposal = Proposal.fromJson(baseJson());

      expect(proposal.id, 'proposal_1');
      expect(proposal.listingId, '6a6d3fced07caabbbdfc586b');
      expect(proposal.freelancerId, 'freelancer_1');
      expect(proposal.freelancerName, 'Grace Hopper');
      expect(proposal.coverLetter, "I'm a great fit for this project.");
      expect(proposal.proposedRate, 1500);
      expect(proposal.status, ProposalStatus.pending);
    });

    test('defaults status to pending when absent', () {
      final json = baseJson()..remove('status');
      expect(Proposal.fromJson(json).status, ProposalStatus.pending);
    });
  });

  group('proposalStatusLabel', () {
    test('produces a human-readable label for every known status', () {
      expect(proposalStatusLabel(ProposalStatus.pending), 'Pending');
      expect(proposalStatusLabel(ProposalStatus.accepted), 'Accepted');
      expect(proposalStatusLabel(ProposalStatus.rejected), 'Rejected');
    });

    test('falls back to the raw value for an unknown status', () {
      expect(proposalStatusLabel('withdrawn'), 'withdrawn');
    });
  });
}
