import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rbac.dart';
import '../../data/repository_providers.dart';
import '../../models/listing.dart';
import '../../widgets/async_value_view.dart';
import '../auth/auth_controller.dart';
import 'listing_detail_controller.dart';
import 'listings_controller.dart';
import 'my_listings_controller.dart';

enum ListingFormMode { create, edit }

/// Post a new listing, or edit an existing one (client-owner only) - mirrors
/// the web app's `listings/new/page.tsx` and `listings/[id]/edit/page.tsx`.
class ListingFormScreen extends ConsumerWidget {
  const ListingFormScreen({required this.mode, this.listingId, super.key});

  final ListingFormMode mode;
  final String? listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (authState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(mode == ListingFormMode.create
              ? 'Post a listing'
              : 'Edit listing'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null || !user.isAuthenticated || !isClient(user.customRole)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(mode == ListingFormMode.create
              ? 'Post a listing'
              : 'Edit listing'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sign in with a client account to continue.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mode == ListingFormMode.create) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post a listing')),
        body: _ListingFormBody(
          mode: mode,
          listingId: null,
          initial: null,
          clientId: user.id,
          clientName: user.fullName,
        ),
      );
    }

    final id = listingId;
    if (id == null) {
      return const Scaffold(body: Center(child: Text('Missing listing id.')));
    }

    final detailAsync = ref.watch(listingDetailControllerProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit listing')),
      body: AsyncValueView(
        value: detailAsync,
        onRetry: () => ref.invalidate(listingDetailControllerProvider(id)),
        data: (context, state) {
          final listing = state.listing;
          if (listing == null) {
            return const Center(child: Text("This listing couldn't be found."));
          }
          if (listing.clientId != user.id) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Only the client who posted this listing can edit it.'),
              ),
            );
          }
          return _ListingFormBody(
            mode: mode,
            listingId: id,
            initial: listing,
            clientId: user.id,
            clientName: user.fullName,
          );
        },
      ),
    );
  }
}

class _ListingFormBody extends ConsumerStatefulWidget {
  const _ListingFormBody({
    required this.mode,
    required this.listingId,
    required this.initial,
    required this.clientId,
    required this.clientName,
  });

  final ListingFormMode mode;
  final String? listingId;
  final Listing? initial;
  final String clientId;
  final String clientName;

  @override
  ConsumerState<_ListingFormBody> createState() => _ListingFormBodyState();
}

class _ListingFormBodyState extends ConsumerState<_ListingFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _budgetController;
  late final TextEditingController _categoryController;
  late String _status;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _budgetController = TextEditingController(
      text: initial == null ? '' : initial.budget.toStringAsFixed(0),
    );
    _categoryController = TextEditingController(text: initial?.category ?? '');
    _status = initial?.status ?? ListingStatus.open;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _categoryController.dispose();
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
      final repo = ref.read(listingRepositoryProvider);
      final category = _categoryController.text.trim();
      final budget = double.parse(_budgetController.text);

      if (widget.mode == ListingFormMode.create) {
        final created = await authNotifier.callAuthorized(
          (token) => repo.create(
            token: token,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            budget: budget,
            category: category.isEmpty ? null : category,
            clientId: widget.clientId,
            clientName: widget.clientName,
          ),
        );
        ref.invalidate(listingsControllerProvider);
        if (mounted) context.go('/listings/${created.id}');
      } else {
        final id = widget.listingId;
        if (id == null) {
          throw StateError('Edit mode requires a listingId.');
        }
        await authNotifier.callAuthorized(
          (token) => repo.update(
            token: token,
            id: id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            budget: budget,
            category: category.isEmpty ? null : category,
            status: _status,
          ),
        );
        ref.invalidate(listingDetailControllerProvider(id));
        ref.invalidate(listingsControllerProvider);
        ref.invalidate(myListingsControllerProvider);
        if (mounted) context.go('/listings/$id');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                if (trimmed.length > 120) return 'Title is too long';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the scope, deliverables, and timeline…',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 20) {
                  return 'Description must be at least 20 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budgetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget (USD)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Budget must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Web Development',
              ),
            ),
            if (widget.mode == ListingFormMode.edit) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final status in ListingStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(listingStatusLabel(status)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.mode == ListingFormMode.create
                          ? 'Post listing'
                          : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
