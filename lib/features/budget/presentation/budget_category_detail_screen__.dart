import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../domain/models/category_budget.dart';
import '../../../domain/models/monthly_planned_item.dart';
import '../../../domain/models/transaction_line_item.dart';
import '../application/budget_providers.dart';
import '../application/planned_item_actuals_provider.dart';

class BudgetCategoryDetailScreen extends ConsumerWidget {
  const BudgetCategoryDetailScreen({
    super.key,
    required this.category,
    required this.year,
    required this.month,
  });

  final CategoryBudget category;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryId = category.categoryId;

    if (categoryId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(category.name),
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: Text(
            'Item planning is not available for this category.',
          ),
        ),
      );
    }

    final query = (
      year: year,
      month: month,
      categoryId: categoryId,
    );

    final itemsAsync = ref.watch(
      plannedItemsProvider(query),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(category.name),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget-category-add-item',
        onPressed: () async {
          final currentItems =
              itemsAsync.value ?? const <MonthlyPlannedItem>[];

          await _showPlannedItemDialog(
            context: context,
            ref: ref,
            categoryId: categoryId,
            year: year,
            month: month,
            nextSortOrder: currentItems.length,
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _ErrorState(
          onRetry: () {
            ref.invalidate(plannedItemsProvider(query));
          },
        ),
        data: (items) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(plannedItemsProvider(query));

              for (final item in items) {
                ref.invalidate(
                  plannedItemActualsProvider(item.id),
                );
              }

              await ref.read(
                plannedItemsProvider(query).future,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                100,
              ),
              children: [
                _MonthLabel(
                  year: year,
                  month: month,
                ),

                const SizedBox(height: 12),

                _EnvelopeCard(
                  category: category,
                ),

                const SizedBox(height: 14),

                _PlanSummaryCard(
                  category: category,
                  items: items,
                ),

                const SizedBox(height: 22),

                Text(
                  'PLANNED ITEMS',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),

                const SizedBox(height: 10),

                if (items.isEmpty)
                  const _EmptyPlanCard()
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: _PlannedItemCard(
                        item: item,
                        onEdit: () {
                          _showPlannedItemDialog(
                            context: context,
                            ref: ref,
                            categoryId: categoryId,
                            year: year,
                            month: month,
                            nextSortOrder: item.sortOrder,
                            existing: item,
                          );
                        },
                        onDelete: () {
                          _deletePlannedItem(
                            context: context,
                            ref: ref,
                            item: item,
                          );
                        },
                        onToggleCompleted: (value) {
                          _setCompleted(
                            context: context,
                            ref: ref,
                            item: item,
                            value: value,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  const _MonthLabel({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatMonth(year, month),
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(
            color: AppTheme.textSecondary,
          ),
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({
    required this.category,
  });

  final CategoryBudget category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY ENVELOPE',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _EnvelopeValue(
                  label: 'Starting',
                  value: category.startingAvailable,
                ),
              ),
              Expanded(
                child: _EnvelopeValue(
                  label: 'Assigned',
                  value: category.assigned,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _EnvelopeValue(
                  label: 'Spent',
                  value: category.spent,
                ),
              ),
              Expanded(
                child: _EnvelopeValue(
                  label: 'Available',
                  value: category.available,
                  emphasize: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnvelopeValue extends StatelessWidget {
  const _EnvelopeValue({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          Money.formatZmw(value),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                color: value < 0
                    ? Colors.red.shade700
                    : AppTheme.textPrimary,
                fontWeight: emphasize
                    ? FontWeight.w800
                    : FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.category,
    required this.items,
  });

  final CategoryBudget category;
  final List<MonthlyPlannedItem> items;

  @override
  Widget build(BuildContext context) {
    var knownPlannedTotal = 0;
    var unpricedItems = 0;

    for (final item in items) {
      final amount = item.plannedAmount;

      if (amount == null) {
        unpricedItems++;
      } else {
        knownPlannedTotal += amount;
      }
    }

    final difference =
        category.available - knownPlannedTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEM PLAN',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),

          const SizedBox(height: 14),

          _SummaryRow(
            label: 'Known planned total',
            value: Money.formatZmw(
              knownPlannedTotal,
            ),
          ),

          const SizedBox(height: 10),

          _SummaryRow(
            label: difference >= 0
                ? 'Unplanned balance'
                : 'Funding gap',
            value: Money.formatZmw(
              difference.abs(),
            ),
            warning: difference < 0,
          ),

          if (unpricedItems > 0) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Unpriced items',
              value: '$unpricedItems',
            ),
          ],

          if (difference < 0) ...[
            const SizedBox(height: 14),
            Text(
              'Your item plan is larger than the category money currently available. '
              'Nomi will warn you, but it will not block the plan.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: warning
                    ? Colors.orange.shade800
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PlannedItemCard extends ConsumerWidget {
  const _PlannedItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleCompleted,
  });

  final MonthlyPlannedItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actualsAsync = ref.watch(
      plannedItemActualsProvider(item.id),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              8,
              12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isCompleted,
                  onChanged: (value) {
                    if (value != null) {
                      onToggleCompleted(value);
                    }
                  },
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 6,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameSnapshot,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color:
                                    AppTheme.textPrimary,
                                fontWeight:
                                    FontWeight.w700,
                                decoration:
                                    item.isCompleted
                                    ? TextDecoration
                                          .lineThrough
                                    : null,
                              ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _plannedDescription(item),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme
                                    .textSecondary,
                              ),
                        ),

                        if (item.note != null &&
                            item.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            item.note!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme
                                      .textSecondary,
                                  fontStyle:
                                      FontStyle.italic,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                PopupMenuButton<_ItemAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _ItemAction.edit:
                        onEdit();
                        break;
                      case _ItemAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ItemAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ItemAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          actualsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not load actual purchases.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                AppTheme.textSecondary,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(
                        plannedItemActualsProvider(
                          item.id,
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (actuals) {
              return _ActualProgressSection(
                item: item,
                actuals: actuals,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActualProgressSection extends StatelessWidget {
  const _ActualProgressSection({
    required this.item,
    required this.actuals,
  });

  final MonthlyPlannedItem item;
  final List<TransactionLineItem> actuals;

  @override
  Widget build(BuildContext context) {
    final actualAmount = actuals.fold<int>(
      0,
      (sum, line) => sum + line.amount,
    );

    final quantityResult = _actualQuantity(
      item,
      actuals,
    );

    final plannedAmount = item.plannedAmount;
    final amountVariance = plannedAmount == null
        ? null
        : actualAmount - plannedAmount;

    final plannedQuantity = item.plannedQuantity;
    final actualQuantity = quantityResult.quantity;

    double? quantityProgress;

    if (plannedQuantity != null &&
        plannedQuantity > 0 &&
        actualQuantity != null) {
      quantityProgress =
          actualQuantity / plannedQuantity;
    }

    final derivedComplete =
        quantityProgress != null &&
        quantityProgress >= 1;

    final status = item.isCompleted
        ? 'Completed manually'
        : derivedComplete
        ? 'Quantity fulfilled'
        : actuals.isEmpty
        ? 'Not purchased yet'
        : 'In progress';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isCompleted || derivedComplete
                    ? Icons.check_circle_outline_rounded
                    : actuals.isEmpty
                    ? Icons.hourglass_empty_rounded
                    : Icons.timelapse_rounded,
                size: 18,
                color:
                    item.isCompleted || derivedComplete
                    ? Colors.green.shade700
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                status,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color:
                          item.isCompleted ||
                              derivedComplete
                          ? Colors.green.shade700
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _ActualRow(
            label: 'Actual spent',
            value: Money.formatZmw(
              actualAmount,
            ),
          ),

          if (plannedAmount != null) ...[
            const SizedBox(height: 8),
            _ActualRow(
              label: 'Planned',
              value: Money.formatZmw(
                plannedAmount,
              ),
            ),
            const SizedBox(height: 8),
            _VarianceRow(
              variance: amountVariance!,
            ),
          ],

          if (plannedQuantity != null) ...[
            const SizedBox(height: 12),

            if (quantityResult.comparable &&
                actualQuantity != null) ...[
              _ActualRow(
                label: 'Quantity',
                value:
                    '${Quantity.format(actualQuantity)} / '
                    '${Quantity.format(plannedQuantity)}'
                    '${_unitSuffix(item.unitSnapshot)}',
              ),

              const SizedBox(height: 10),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: quantityProgress!
                      .clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      AppTheme.border,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '${(quantityProgress * 100).round()}% of planned quantity',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color:
                          AppTheme.textSecondary,
                    ),
              ),
            ] else if (actuals.isNotEmpty) ...[
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Quantity progress is unavailable because one or more actual purchases '
                      'do not use a comparable quantity/unit.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                AppTheme.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],

          if (actuals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${actuals.length} linked ${actuals.length == 1 ? 'purchase' : 'purchases'}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActualRow extends StatelessWidget {
  const _ActualRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _VarianceRow extends StatelessWidget {
  const _VarianceRow({
    required this.variance,
  });

  final int variance;

  @override
  Widget build(BuildContext context) {
    final String label;
    final String value;
    final Color color;

    if (variance > 0) {
      label = 'Over plan';
      value = '+${Money.formatZmw(variance)}';
      color = Colors.red.shade700;
    } else if (variance < 0) {
      label = 'Under plan';
      value = Money.formatZmw(variance.abs());
      color = Colors.green.shade700;
    } else {
      label = 'Variance';
      value = Money.formatZmw(0);
      color = AppTheme.textPrimary;
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 30,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'No planned items yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add the things you intend to buy or pay for from this category.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load the item plan.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ItemAction {
  edit,
  delete,
}

class _QuantityResult {
  const _QuantityResult({
    required this.comparable,
    required this.quantity,
  });

  final bool comparable;
  final int? quantity;
}

_QuantityResult _actualQuantity(
  MonthlyPlannedItem item,
  List<TransactionLineItem> actuals,
) {
  if (actuals.isEmpty) {
    return const _QuantityResult(
      comparable: true,
      quantity: 0,
    );
  }

  final plannedUnit =
      _normalizeUnit(item.unitSnapshot);

  var total = 0;

  for (final actual in actuals) {
    final quantity = actual.quantity;

    if (quantity == null) {
      return const _QuantityResult(
        comparable: false,
        quantity: null,
      );
    }

    final actualUnit =
        _normalizeUnit(actual.unitSnapshot);

    if (actualUnit != plannedUnit) {
      return const _QuantityResult(
        comparable: false,
        quantity: null,
      );
    }

    total += quantity;
  }

  return _QuantityResult(
    comparable: true,
    quantity: total,
  );
}

String? _normalizeUnit(String? unit) {
  final cleaned = unit?.trim().toLowerCase();

  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }

  return cleaned;
}

String _unitSuffix(String? unit) {
  final cleaned = unit?.trim();

  if (cleaned == null || cleaned.isEmpty) {
    return '';
  }

  return ' $cleaned';
}

String _plannedDescription(
  MonthlyPlannedItem item,
) {
  final pieces = <String>[];

  if (item.plannedQuantity != null) {
    pieces.add(
      '${Quantity.format(item.plannedQuantity!)}'
      '${_unitSuffix(item.unitSnapshot)}',
    );
  }

  if (item.plannedAmount != null) {
    pieces.add(
      Money.formatZmw(item.plannedAmount!),
    );
  } else {
    pieces.add('Price unknown');
  }

  return pieces.join(' • ');
}

Future<void> _setCompleted({
  required BuildContext context,
  required WidgetRef ref,
  required MonthlyPlannedItem item,
  required bool value,
}) async {
  try {
    final repository = ref.read(
      budgetRepositoryProvider,
    );

    await repository.updatePlannedItem(
      item.copyWith(
        isCompleted: value,
        updatedAt: DateTime.now(),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _friendlyError(
            error,
            fallback:
                'Could not update item completion.',
          ),
        ),
      ),
    );
  }
}

Future<void> _deletePlannedItem({
  required BuildContext context,
  required WidgetRef ref,
  required MonthlyPlannedItem item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete planned item?'),
        content: Text(
          'Delete "${item.nameSnapshot}" from this month’s plan? '
          'Any historical purchases remain preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(budgetRepositoryProvider)
        .deletePlannedItem(item.id);

    ref.invalidate(
      plannedItemActualsProvider(item.id),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _friendlyError(
            error,
            fallback:
                'Could not delete planned item.',
          ),
        ),
      ),
    );
  }
}

Future<void> _showPlannedItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int categoryId,
  required int year,
  required int month,
  required int nextSortOrder,
  MonthlyPlannedItem? existing,
}) async {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController(
    text: existing?.nameSnapshot ?? '',
  );

  final quantityController = TextEditingController(
    text: existing?.plannedQuantity == null
        ? ''
        : Quantity.format(
            existing!.plannedQuantity!,
          ),
  );

  final unitController = TextEditingController(
    text: existing?.unitSnapshot ?? '',
  );

  final amountController = TextEditingController(
    text: existing?.plannedAmount == null
        ? ''
        : Money.formatMinorUnits(
            existing!.plannedAmount!,
          ),
  );

  final noteController = TextEditingController(
    text: existing?.note ?? '',
  );

  var saving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving ||
                  !(formKey.currentState?.validate() ??
                      false)) {
                return;
              }

              final name =
                  nameController.text.trim();

              int? plannedQuantity;

              final quantityText =
                  quantityController.text.trim();

              if (quantityText.isNotEmpty) {
                final parsed =
                    double.tryParse(quantityText);

                if (parsed == null || parsed <= 0) {
                  return;
                }

                plannedQuantity =
                    Quantity.toStored(parsed);
              }

              int? plannedAmount;

              final amountText =
                  amountController.text.trim();

              if (amountText.isNotEmpty) {
                plannedAmount =
                    Money.tryParseToMinorUnits(
                  amountText,
                );

                if (plannedAmount == null ||
                    plannedAmount < 0) {
                  return;
                }
              }

              final unit = _cleanText(
                unitController.text,
              );

              final note = _cleanText(
                noteController.text,
              );

              setDialogState(() {
                saving = true;
              });

              try {
                final repository = ref.read(
                  budgetRepositoryProvider,
                );

                if (existing == null) {
                  final budgetMonth =
                      await repository
                          .getOrCreateBudgetMonth(
                    year: year,
                    month: month,
                  );

                  await repository.createPlannedItem(
                    budgetMonthId:
                        budgetMonth.id,
                    categoryId: categoryId,
                    itemDefinitionId: null,
                    nameSnapshot: name,
                    plannedQuantity:
                        plannedQuantity,
                    unitSnapshot: unit,
                    plannedAmount: plannedAmount,
                    isCompleted: false,
                    sortOrder: nextSortOrder,
                    note: note,
                  );
                } else {
                  await repository.updatePlannedItem(
                    existing!.copyWith(
                      nameSnapshot: name,
                      plannedQuantity:
                          plannedQuantity,
                      clearPlannedQuantity:
                          plannedQuantity == null,
                      unitSnapshot: unit,
                      clearUnitSnapshot:
                          unit == null,
                      plannedAmount: plannedAmount,
                      clearPlannedAmount:
                          plannedAmount == null,
                      note: note,
                      clearNote: note == null,
                      updatedAt: DateTime.now(),
                    ),
                  );

                  ref.invalidate(
                    plannedItemActualsProvider(
                      existing!.id,
                    ),
                  );
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      _friendlyError(
                        error,
                        fallback:
                            'Could not save planned item.',
                      ),
                    ),
                  ),
                );

                setDialogState(() {
                  saving = false;
                });
              }
            }

            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Add planned item'
                    : 'Edit planned item',
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller:
                              nameController,
                          autofocus:
                              existing == null,
                          textCapitalization:
                              TextCapitalization
                                  .words,
                          decoration:
                              const InputDecoration(
                            labelText: 'Item name',
                            hintText:
                                'e.g. Sugar',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Enter an item name';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller:
                                    quantityController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Quantity',
                                  hintText:
                                      'Optional',
                                ),
                                validator:
                                    (value) {
                                  final text =
                                      value
                                          ?.trim() ??
                                      '';

                                  if (text.isEmpty) {
                                    return null;
                                  }

                                  final parsed =
                                      double.tryParse(
                                    text,
                                  );

                                  if (parsed ==
                                          null ||
                                      parsed <= 0) {
                                    return 'Invalid';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextFormField(
                                controller:
                                    unitController,
                                textCapitalization:
                                    TextCapitalization
                                        .none,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Unit',
                                  hintText:
                                      'kg, pack...',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller:
                              amountController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Planned amount',
                            prefixText: 'K ',
                            hintText:
                                'Leave blank if unknown',
                          ),
                          validator: (value) {
                            final text =
                                value?.trim() ?? '';

                            if (text.isEmpty) {
                              return null;
                            }

                            final amount = Money
                                .tryParseToMinorUnits(
                              text,
                            );

                            if (amount == null ||
                                amount < 0) {
                              return 'Enter a valid amount';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller:
                              noteController,
                          maxLines: 2,
                          textCapitalization:
                              TextCapitalization
                                  .sentences,
                          decoration:
                              const InputDecoration(
                            labelText: 'Note',
                            hintText: 'Optional',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          existing == null
                              ? 'Add'
                              : 'Save',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    amountController.dispose();
    noteController.dispose();
  }
}

String? _cleanText(String value) {
  final cleaned = value.trim();

  return cleaned.isEmpty ? null : cleaned;
}

String _friendlyError(
  Object error, {
  required String fallback,
}) {
  if (error is ArgumentError) {
    return error.message?.toString() ?? fallback;
  }

  if (error is StateError) {
    return error.message;
  }

  return fallback;
}

String _formatMonth(int year, int month) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[month - 1]} $year';
}
