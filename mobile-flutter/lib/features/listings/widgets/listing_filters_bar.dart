import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../listings_controller.dart';

const Duration _searchDebounce = Duration(milliseconds: 300);

/// Search box + category dropdown + budget range - mirrors the web app's
/// `ListingFilters.tsx`. Debounces the search field the same 300ms the web
/// app's `useDebounce` does, so every keystroke doesn't fire its own search
/// request.
class ListingFiltersBar extends ConsumerStatefulWidget {
  const ListingFiltersBar({super.key});

  @override
  ConsumerState<ListingFiltersBar> createState() => _ListingFiltersBarState();
}

class _ListingFiltersBarState extends ConsumerState<ListingFiltersBar> {
  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, () {
      final current = ref.read(listingsQueryProvider);
      ref.read(listingsQueryProvider.notifier).state = current.copyWith(
        search: value,
        page: 1,
      );
    });
  }

  void _onCategoryChanged(String? value) {
    final current = ref.read(listingsQueryProvider);
    ref.read(listingsQueryProvider.notifier).state = current.copyWith(
      category: value ?? '',
      page: 1,
    );
  }

  void _onBudgetChanged() {
    final current = ref.read(listingsQueryProvider);
    ref.read(listingsQueryProvider.notifier).state = current.copyWith(
      minBudget: _minController.text,
      maxBudget: _maxController.text,
      page: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categorySampleProvider);
    final categories = categoriesAsync.valueOrNull ?? const <String>[];
    final query = ref.watch(listingsQueryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search title or description…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: query.category.isEmpty ? null : query.category,
                  decoration: const InputDecoration(hintText: 'All categories'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All categories')),
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: _onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Min budget'),
                  onChanged: (_) => _onBudgetChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Max budget'),
                  onChanged: (_) => _onBudgetChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
