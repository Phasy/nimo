import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_category.dart';
import '../application/category_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _selectedType = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(
      categoryGroupsProvider(_selectedType),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _CategoryTypeSelector(
            selectedType: _selectedType,
            onChanged: (type) {
              setState(() {
                _selectedType = type;
              });
            },
          ),
          Expanded(
            child: groupsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => _ErrorState(
                message: 'Could not load categories.',
                onRetry: () {
                  ref.invalidate(
                    categoryGroupsProvider(_selectedType),
                  );
                },
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return const _EmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(categoryInitializationProvider);
                    ref.invalidate(
                      categoryGroupsProvider(_selectedType),
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      32,
                    ),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = groups[index];

                      return _CategoryGroupCard(
                        group: group,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showComingSoon(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Adding categories is coming next.',
        ),
      ),
    );
  }
}

class _CategoryTypeSelector extends StatelessWidget {
  const _CategoryTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final CategoryType selectedType;
  final ValueChanged<CategoryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SelectorButton(
                label: 'Expense',
                selected:
                selectedType == CategoryType.expense,
                onTap: () {
                  onChanged(CategoryType.expense);
                },
              ),
            ),
            Expanded(
              child: _SelectorButton(
                label: 'Income',
                selected:
                selectedType == CategoryType.income,
                onTap: () {
                  onChanged(CategoryType.income);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? Colors.white
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 12,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF101828)
                  : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGroupCard extends ConsumerWidget {
  const _CategoryGroupCard({
    required this.group,
  });

  final CategoryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      categoriesProvider(group.id),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEAECF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(
            group: group,
          ),
          const Divider(
            height: 1,
            color: Color(0xFFEAECF0),
          ),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Could not load categories.',
                style: TextStyle(
                  color: Color(0xFFF04438),
                ),
              ),
            ),
            data: (categories) {
              if (categories.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No active categories in this group.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (
                  var index = 0;
                  index < categories.length;
                  index++
                  ) ...[
                    _CategoryRow(
                      category: categories[index],
                    ),
                    if (index != categories.length - 1)
                      const Divider(
                        height: 1,
                        indent: 52,
                        color: Color(0xFFF2F4F7),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
  });

  final CategoryGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        8,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF101828),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Group editing is coming next.',
                  ),
                ),
              );
            },
            tooltip: 'Group options',
            icon: const Icon(
              Icons.more_horiz,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
  });

  final FinanceCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Edit ${category.name} is coming next.',
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.label_outline,
                size: 16,
                color: Color(0xFF079455),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF98A2B3),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(
            horizontal: 120,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.category_outlined,
            color: Color(0xFF079455),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No categories yet',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your categories will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: Color(0xFFF04438),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}