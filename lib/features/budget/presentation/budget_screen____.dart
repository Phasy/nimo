import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/budget_group_summary.dart';
import '../../../domain/models/category_budget.dart';
import '../../../domain/models/monthly_budget_summary.dart';
import '../application/budget_providers.dart';
import 'budget_category_detail_screen.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(budgetInitializationProvider);

    return SafeArea(
      child: initialization.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _BudgetErrorState(
          error: error,
          onRetry: () {
            ref.invalidate(budgetInitializationProvider);
          },
        ),
        data: (_) => const _BudgetContent(),
      ),
    );
  }
}

class _BudgetContent extends ConsumerWidget {
  const _BudgetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);

    final budget = ref.watch(selectedMonthlyBudgetProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Plan every kwacha before you spend it.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              _MonthSelector(
                selectedMonth: selectedMonth,
                onPrevious: () {
                  ref
                      .read(selectedBudgetMonthProvider.notifier)
                      .previousMonth();
                },
                onNext: () {
                  ref.read(selectedBudgetMonthProvider.notifier).nextMonth();
                },
                onCurrent: () {
                  ref.read(selectedBudgetMonthProvider.notifier).currentMonth();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: budget.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              return _BudgetErrorState(
                error: error,
                onRetry: () {
                  ref.invalidate(
                    monthlyBudgetProvider((
                      year: selectedMonth.year,
                      month: selectedMonth.month,
                    )),
                  );
                },
              );
            },
            data: (summary) {
              return _BudgetMonthView(summary: summary);
            },
          ),
        ),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Row(
      children: [
        _MonthButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous month',
          onPressed: onPrevious,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                _formatMonth(selectedMonth),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        _MonthButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onPressed: onNext,
        ),

        if (!isCurrentMonth) ...[
          const SizedBox(width: 8),
          _MonthButton(
            icon: Icons.today_rounded,
            tooltip: 'Current month',
            onPressed: onCurrent,
          ),
        ],
      ],
    );
  }

  static String _formatMonth(DateTime date) {
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

    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BudgetMonthView extends ConsumerWidget {
  const _BudgetMonthView({required this.summary});

  final MonthlyBudgetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          monthlyBudgetProvider((year: summary.year, month: summary.month)),
        );

        await ref.read(
          monthlyBudgetProvider((
            year: summary.year,
            month: summary.month,
          )).future,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          _LeftToAssignCard(summary: summary),

          const SizedBox(height: 16),

          _BudgetTotalsRow(summary: summary),

          const SizedBox(height: 24),

          if (summary.groups.isEmpty)
            const _EmptyBudgetState()
          else
            for (final group in summary.groups) ...[
              _BudgetGroupCard(
                group: group,
                onEditAssigned: (category) {
                  _showAllocationDialog(
                    context: context,
                    ref: ref,
                    summary: summary,
                    category: category,
                  );
                },
                onOpenCategory: (category) {
                  if (category.categoryId == null) {
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BudgetCategoryDetailScreen(
                        category: category,
                        year: summary.year,
                        month: summary.month,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _LeftToAssignCard extends StatelessWidget {
  const _LeftToAssignCard({required this.summary});

  final MonthlyBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final leftToAssign = summary.leftToAssign;

    final statusText = switch (leftToAssign) {
      > 0 => 'Ready to assign',
      0 => 'Every kwacha has a job',
      _ => 'Over assigned',
    };

    final statusIcon = switch (leftToAssign) {
      > 0 => Icons.account_balance_wallet_outlined,
      0 => Icons.check_circle_outline_rounded,
      _ => Icons.warning_amber_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'LEFT TO ASSIGN',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _money(leftToAssign),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            statusText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),

          if (summary.grossIncome != 0) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Income this month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  _money(summary.grossIncome),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
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

class _BudgetTotalsRow extends StatelessWidget {
  const _BudgetTotalsRow({required this.summary});

  final MonthlyBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryMetric(label: 'Assigned', value: summary.assigned),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(label: 'Spent', value: summary.spent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: 'Available',
            value: summary.totalAvailable,
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _money(value),
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetGroupCard extends StatelessWidget {
  const _BudgetGroupCard({
    required this.group,
    required this.onEditAssigned,
    required this.onOpenCategory,
  });

  final BudgetGroupSummary group;

  final ValueChanged<CategoryBudget> onEditAssigned;

  final ValueChanged<CategoryBudget> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _BudgetGroupHeader(group: group),

          const Divider(height: 1, color: AppTheme.border),

          const _CategoryColumnHeader(),

          for (var index = 0; index < group.categories.length; index++) ...[
            if (index != 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppTheme.border,
              ),
            _CategoryBudgetRow(
              category: group.categories[index],
              onEditAssigned: onEditAssigned,
              onOpenCategory: onOpenCategory,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetGroupHeader extends StatelessWidget {
  const _BudgetGroupHeader({required this.group});

  final BudgetGroupSummary group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money(group.available),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryColumnHeader extends StatelessWidget {
  const _CategoryColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppTheme.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('Category', style: style)),
          Expanded(
            flex: 4,
            child: Text('Assigned', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 4,
            child: Text('Spent', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 4,
            child: Text('Available', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.onEditAssigned,
    required this.onOpenCategory,
  });

  final CategoryBudget category;

  final ValueChanged<CategoryBudget> onEditAssigned;

  final ValueChanged<CategoryBudget> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final canAssign = category.categoryId != null && category.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Row(
              children: [
                if (category.isOverspent) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: category.isActive
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 4,
            child: _AssignedCell(
              value: category.assigned,
              enabled: canAssign,
              onTap: () {
                if (canAssign) {
                  onEditAssigned(category);
                }
              },
            ),
          ),

          Expanded(flex: 4, child: _MoneyCell(value: category.spent)),

          Expanded(
            flex: 4,
            child: _MoneyCell(value: category.available, emphasized: true),
          ),
        ],
      ),
    );
  }
}

class _AssignedCell extends StatelessWidget {
  const _AssignedCell({
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _MoneyCell(value: value);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _compactMoney(value),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.edit_outlined,
              size: 12,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.value, this.emphasized = false});

  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Text(
      _compactMoney(value),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppTheme.textPrimary,
        fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  const _EmptyBudgetState();

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
            Icons.account_balance_wallet_outlined,
            size: 36,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing to budget yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your expense categories will appear here.',
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

class _BudgetErrorState extends StatelessWidget {
  const _BudgetErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load budget',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAllocationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MonthlyBudgetSummary summary,
  required CategoryBudget category,
}) async {
  final categoryId = category.categoryId;

  if (categoryId == null) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => _AllocationDialog(
      ref: ref,
      summary: summary,
      category: category,
      categoryId: categoryId,
    ),
  );
}

class _AllocationDialog extends StatefulWidget {
  const _AllocationDialog({
    required this.ref,
    required this.summary,
    required this.category,
    required this.categoryId,
  });

  final WidgetRef ref;
  final MonthlyBudgetSummary summary;
  final CategoryBudget category;
  final int categoryId;

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.category.assigned == 0
          ? ''
          : Money.formatMinorUnits(widget.category.assigned),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final rawValue = _controller.text.trim();
    final amount = rawValue.isEmpty
        ? 0
        : Money.tryParseToMinorUnits(rawValue);

    if (amount == null) {
      setState(() {
        _errorText =
            'Enter a valid amount, for example 500 or 1250.50.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.ref
          .read(budgetAllocationControllerProvider.notifier)
          .setAllocation(
            year: widget.summary.year,
            month: widget.summary.month,
            categoryId: widget.categoryId,
            assignedAmount: amount,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the amount assigned to this category for '
            '${_formatMonthShort(widget.summary.year, widget.summary.month)}.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'Assigned amount',
              prefixText: 'K ',
              hintText: '0.00',
              errorText: _errorText,
            ),
            onSubmitted: (_) {
              if (!_isSaving) {
                _save();
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Current available: ${_money(widget.category.available)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          if (widget.category.startingAvailable != 0) ...[
            const SizedBox(height: 4),
            Text(
              'Carried forward: '
              '${_money(widget.category.startingAvailable)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

String _money(int value) {
  return Money.formatZmw(value);
}

String _compactMoney(int value) {
  final negative = value < 0;
  final absolute = value.abs();

  String formatted;

  if (absolute >= 100000000) {
    formatted = 'K${(absolute / 100000000).toStringAsFixed(1)}m';
  } else if (absolute >= 100000) {
    formatted = 'K${(absolute / 100000).toStringAsFixed(1)}k';
  } else {
    return Money.formatZmw(value);
  }

  return negative ? '-$formatted' : formatted;
}

String _formatMonthShort(int year, int month) {
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
