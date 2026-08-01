import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repository_providers.dart';
import '../../../models/mudbase_user.dart';
import '../../auth/auth_controller.dart';
import '../../listings/listing_detail_controller.dart';

/// A freelancer's proposal submission form on a listing's detail screen -
/// mirrors the web app's `ProposalForm.tsx`.
class ProposalSubmitForm extends ConsumerStatefulWidget {
  const ProposalSubmitForm({
    required this.listingId,
    required this.currentUser,
    super.key,
  });

  final String listingId;
  final MudbaseUser currentUser;

  @override
  ConsumerState<ProposalSubmitForm> createState() => _ProposalSubmitFormState();
}

class _ProposalSubmitFormState extends ConsumerState<ProposalSubmitForm> {
  final _formKey = GlobalKey<FormState>();
  final _coverLetterController = TextEditingController();
  final _rateController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _coverLetterController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final authNotifier = ref.read(authControllerProvider.notifier);
      final repo = ref.read(proposalRepositoryProvider);
      await authNotifier.callAuthorized(
        (token) => repo.create(
          token: token,
          listingId: widget.listingId,
          freelancerId: widget.currentUser.id,
          freelancerName: widget.currentUser.fullName,
          coverLetter: _coverLetterController.text.trim(),
          proposedRate: double.parse(_rateController.text),
        ),
      );
      ref.invalidate(listingDetailControllerProvider(widget.listingId));
      if (mounted) {
        _coverLetterController.clear();
        _rateController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal submitted.')),
        );
      }
    } on Object catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _coverLetterController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Cover letter',
              hintText: "Explain why you're a good fit for this job…",
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.length < 20) {
                return 'Cover letter must be at least 20 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Proposed rate (USD)'),
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Proposed rate must be greater than 0';
              }
              return null;
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit proposal'),
          ),
        ],
      ),
    );
  }
}
