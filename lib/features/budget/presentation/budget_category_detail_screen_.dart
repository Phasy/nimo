import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../domain/models/category_budget.dart';
import '../../../domain/models/monthly_planned_item.dart';
import '../application/budget_providers.dart';

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
        appBar: AppBar(title: Text(category.name)),
        body: const Center(
          child: Text('Item planning is not available for this category.'),
        ),
      );
    }

    final query = (year: year, month: month, categoryId: categoryId);

    final items = ref.watch(plannedItemsProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (plannedItems) {
          return _CategoryPlanContent(
            category: category,
            year: year,
            month: month,
            items: plannedItems,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget-category-add-item',
        onPressed: () {
          _showItemEditor(
            context: context,
            ref: ref,
            year: year,
            month: month,
            categoryId: categoryId,
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
    );
  }
}

class _CategoryPlanContent extends ConsumerWidget {
  const _CategoryPlanContent({
    required this.category,
    required this.year,
    required this.month,
    required this.items,
  });

  final CategoryBudget category;
  final int year;
  final int month;
  final List<MonthlyPlannedItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownPlannedTotal = items.fold<int>(
      0,
      (total, item) => total + (item.plannedAmount ?? 0),
    );

    final unpricedCount = items
        .where((item) => item.plannedAmount == null)
        .length;

    final unplannedBalance = category.available - knownPlannedTotal;

    final isOverPlanned = unplannedBalance < 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text(
          _formatMonth(year, month),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),

        const SizedBox(height: 16),

        _EnvelopeCard(category: category),

        const SizedBox(height: 14),

        _PlanSummaryCard(
          planned: knownPlannedTotal,
          unplanned: unplannedBalance,
          unpricedCount: unpricedCount,
          isOverPlanned: isOverPlanned,
        ),

        if (isOverPlanned) ...[
          const SizedBox(height: 12),
          const _OverPlanWarning(),
        ],

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                'Planned items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${items.length}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (items.isEmpty)
          const _EmptyPlan()
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index != 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppTheme.border,
                    ),
                  _PlannedItemRow(
                    item: items[index],
                    onToggleCompleted: (completed) {
                      ref
                          .read(plannedItemControllerProvider.notifier)
                          .setCompleted(
                            item: items[index],
                            completed: completed,
                          );
                    },
                    onEdit: () {
                      _showItemEditor(
                        context: context,
                        ref: ref,
                        year: year,
                        month: month,
                        categoryId: category.categoryId!,
                        existingItem: items[index],
                      );
                    },
                    onDelete: () {
                      _confirmDelete(
                        context: context,
                        ref: ref,
                        item: items[index],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({required this.category});

  final CategoryBudget category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _ValueRow(label: 'Starting', value: category.startingAvailable),
          const SizedBox(height: 10),
          _ValueRow(label: 'Assigned', value: category.assigned),
          const SizedBox(height: 10),
          _ValueRow(label: 'Spent', value: -category.spent),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.border),
          ),
          _ValueRow(
            label: 'Available',
            value: category.available,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: emphasized ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          Money.formatZmw(value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.planned,
    required this.unplanned,
    required this.unpricedCount,
    required this.isOverPlanned,
  });

  final int planned;
  final int unplanned;
  final int unpricedCount;
  final bool isOverPlanned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _ValueRow(label: 'Known planned total', value: planned),
          const SizedBox(height: 10),
          _ValueRow(
            label: isOverPlanned ? 'Funding gap' : 'Unplanned balance',
            value: unplanned,
            emphasized: true,
          ),
          if (unpricedCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$unpricedCount ${unpricedCount == 1 ? 'item has' : 'items have'} no planned price yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverPlanWarning extends StatelessWidget {
  const _OverPlanWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your known item plan is greater than the money currently available in this category. Nomi will allow the plan, but the category needs more funding or a smaller plan.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedItemRow extends StatelessWidget {
  const _PlannedItemRow({
    required this.item,
    required this.onToggleCompleted,
    required this.onEdit,
    required this.onDelete,
  });

  final MonthlyPlannedItem item;
  final ValueChanged<bool> onToggleCompleted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameSnapshot,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),

                  finalDetailText(context, item),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              item.plannedAmount == null
                  ? '?'
                  : Money.formatZmw(item.plannedAmount!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget finalDetailText(BuildContext context, MonthlyPlannedItem item) {
    final parts = <String>[];

    if (item.plannedQuantity != null) {
      parts.add(Quantity.format(item.plannedQuantity!));
    }

    if (item.unitSnapshot != null && item.unitSnapshot!.trim().isNotEmpty) {
      parts.add(item.unitSnapshot!);
    }

    if (item.note != null && item.note!.trim().isNotEmpty) {
      parts.add(item.note!);
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        parts.join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 34,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No items planned',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add individual things you expect this category money to pay for.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

Future<void> _showItemEditor({
  required BuildContext context,
  required WidgetRef ref,
  required int year,
  required int month,
  required int categoryId,
  MonthlyPlannedItem? existingItem,
}) async {
  final nameController = TextEditingController(
    text: existingItem?.nameSnapshot ?? '',
  );

  final quantityController = TextEditingController(
    text: existingItem?.plannedQuantity == null
        ? ''
        : Quantity.format(existingItem!.plannedQuantity!),
  );

  final unitController = TextEditingController(
    text: existingItem?.unitSnapshot ?? '',
  );

  final amountController = TextEditingController(
    text: existingItem?.plannedAmount == null
        ? ''
        : Money.formatMinorUnits(existingItem!.plannedAmount!),
  );

  final noteController = TextEditingController(text: existingItem?.note ?? '');

  String? errorText;
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            final name = nameController.text.trim();

            if (name.isEmpty) {
              setState(() {
                errorText = 'Enter an item name.';
              });
              return;
            }

            int? quantity;

            final quantityText = quantityController.text.trim();

            if (quantityText.isNotEmpty) {
              final parsed = double.tryParse(quantityText);

              if (parsed == null || parsed <= 0) {
                setState(() {
                  errorText = 'Quantity must be a number greater than zero.';
                });
                return;
              }

              quantity = Quantity.toStored(parsed);
            }

            int? amount;

            final amountText = amountController.text.trim();

            if (amountText.isNotEmpty) {
              amount = Money.tryParseToMinorUnits(amountText);

              if (amount == null || amount < 0) {
                setState(() {
                  errorText = 'Enter a valid planned amount.';
                });
                return;
              }
            }

            setState(() {
              saving = true;
              errorText = null;
            });

            try {
              final controller = ref.read(
                plannedItemControllerProvider.notifier,
              );

              if (existingItem == null) {
                await controller.createItem(
                  year: year,
                  month: month,
                  categoryId: categoryId,
                  name: name,
                  plannedQuantity: quantity,
                  unit: unitController.text,
                  plannedAmount: amount,
                  note: noteController.text,
                );
              } else {
                await controller.updateItem(
                  year: year,
                  month: month,
                  item: existingItem,
                  name: name,
                  plannedQuantity: quantity,
                  unit: unitController.text,
                  plannedAmount: amount,
                  note: noteController.text,
                );
              }

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            } catch (error) {
              if (!dialogContext.mounted) {
                return;
              }

              setState(() {
                saving = false;
                errorText = error.toString();
              });
            }
          }

          return AlertDialog(
            title: Text(
              existingItem == null ? 'Add planned item' : 'Edit planned item',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Item',
                      hintText: 'Sugar',
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: '5',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            hintText: 'kg',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Planned amount',
                      prefixText: 'K ',
                      hintText: 'Leave blank if unknown',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: noteController,
                    enabled: !saving,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),

                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(existingItem == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  quantityController.dispose();
  unitController.dispose();
  amountController.dispose();
  noteController.dispose();
}

Future<void> _confirmDelete({
  required BuildContext context,
  required WidgetRef ref,
  required MonthlyPlannedItem item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete planned item?'),
        content: Text('Remove "${item.nameSnapshot}" from this month\'s plan?'),
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

  if (confirmed != true) {
    return;
  }

  await ref.read(plannedItemControllerProvider.notifier).deleteItem(item);
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
