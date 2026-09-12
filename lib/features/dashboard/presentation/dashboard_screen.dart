import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/finance_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../domain/models/category_budget.dart';
import '../../../domain/models/monthly_budget_summary.dart';
import '../../accounts/application/account_providers.dart';
import '../../budget/application/budget_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(
      totalAccountBalanceProvider,
    );
    final budgetAsync = ref.watch(currentMonthlyBudgetProvider);

    return Scaffold(
      body: SafeArea(
        child: _DashboardContent(
          totalBalanceAsync: totalBalanceAsync,
          budgetAsync: budgetAsync,
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final AsyncValue<int> totalBalanceAsync;
  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;

  const _DashboardContent({
    required this.totalBalanceAsync,
    required this.budgetAsync,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),

          const SizedBox(height: 26),

          _AvailableCard(
            totalBalanceAsync: totalBalanceAsync,
            budgetAsync: budgetAsync,
          ),

          const SizedBox(height: 28),

          _SectionHeader(
            title: 'This month',
            actionText: _formatMonth(DateTime.now()),
          ),

          const SizedBox(height: 12),

          _MonthlySummary(budgetAsync: budgetAsync),

          const SizedBox(height: 28),

          const _SectionHeader(
            title: 'Budget',
            actionText: 'See all',
          ),

          const SizedBox(height: 12),

          _BudgetSection(budgetAsync: budgetAsync),

          const SizedBox(height: 28),

          const _SectionHeader(
            title: 'Upcoming',
            actionText: 'See all',
          ),

          const SizedBox(height: 12),

          const _UpcomingSection(),

          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Phasy',
                style: Theme
                    .of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailableCard extends StatelessWidget {
  final AsyncValue<int> totalBalanceAsync;
  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;

  const _AvailableCard({
    required this.totalBalanceAsync,
    required this.budgetAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE',
            style: Theme
                .of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          _BudgetMoneyValue(
            budgetAsync: budgetAsync,
            select: (summary) => summary.totalAvailable,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 26),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _LiveTotalMoneyStat(
                  totalBalanceAsync: totalBalanceAsync,
                ),
              ),

              Expanded(
                child: _HeroBudgetStat(
                  label: 'Left to assign',
                  budgetAsync: budgetAsync,
                  select: (summary) => summary.leftToAssign,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveTotalMoneyStat extends StatelessWidget {
  final AsyncValue<int> totalBalanceAsync;

  const _LiveTotalMoneyStat({
    required this.totalBalanceAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total money',
          style: Theme
              .of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),

        const SizedBox(height: 5),

        totalBalanceAsync.when(
          data: (totalBalance) {
            return MoneyText(
              amount: totalBalance,
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            );
          },
          loading: () {
            return SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            );
          },
          error: (error, stackTrace) {
            return Text(
              '—',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeroBudgetStat extends StatelessWidget {
  final String label;
  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;
  final int Function(MonthlyBudgetSummary summary) select;

  const _HeroBudgetStat({
    required this.label,
    required this.budgetAsync,
    required this.select,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme
              .of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 5),
        _BudgetMoneyValue(
          budgetAsync: budgetAsync,
          select: select,
          style: Theme
              .of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.budgetAsync});

  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;

  @override
  Widget build(BuildContext context) {
    return budgetAsync.when(
      loading: () => const _BudgetLoadingCard(),
      error: (error, stackTrace) => const _BudgetUnavailableCard(),
      data: (summary) {
        if (summary == null) {
          return const _BudgetNotInitializedCard();
        }

        return FinanceCard(
          child: Column(
            children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.south_west_rounded,
                  title: 'Income',
                  amount: summary.grossIncome,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.north_east_rounded,
                  title: 'Spent',
                  amount: summary.principalSpent,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),

          SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Fees',
                  amount: summary.fees,
                  color: AppTheme.warning,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Remaining',
                  amount: summary.remainingThisMonth,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int amount;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              MoneyText(
                amount: amount,
                style: Theme
                    .of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.budgetAsync});

  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;

  @override
  Widget build(BuildContext context) {
    return budgetAsync.when(
      loading: () => const _BudgetLoadingCard(),
      error: (error, stackTrace) => const _BudgetUnavailableCard(),
      data: (summary) {
        if (summary == null) {
          return const _BudgetNotInitializedCard();
        }

        final categories = summary.categories
            .where((category) => category.hasActivity)
            .take(3)
            .toList();

        if (categories.isEmpty) {
          return const _EmptyBudgetCard();
        }

        return FinanceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          child: Column(
            children: [
              for (var index = 0; index < categories.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _BudgetRow(category: categories[index]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final CategoryBudget category;

  const _BudgetRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final progress = category.planningCapacity <= 0
        ? 0.0
        : (category.spent / category.planningCapacity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              MoneyText(
                amount: category.available,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
              color: AppTheme.primary,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              MoneyText(
                amount: category.spent,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                ' of ',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              MoneyText(
                amount: category.planningCapacity,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'remaining',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetMoneyValue extends StatelessWidget {
  const _BudgetMoneyValue({
    required this.budgetAsync,
    required this.select,
    required this.style,
  });

  final AsyncValue<MonthlyBudgetSummary?> budgetAsync;
  final int Function(MonthlyBudgetSummary summary) select;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return budgetAsync.when(
      data: (summary) => summary == null
          ? Text('—', style: style)
          : MoneyText(amount: select(summary), style: style),
      loading: () => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      error: (error, stackTrace) => Text('—', style: style),
    );
  }
}

class _BudgetLoadingCard extends StatelessWidget {
  const _BudgetLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const FinanceCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BudgetUnavailableCard extends StatelessWidget {
  const _BudgetUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return const FinanceCard(
      child: Text('Budget information is temporarily unavailable.'),
    );
  }
}

class _BudgetNotInitializedCard extends StatelessWidget {
  const _BudgetNotInitializedCard();

  @override
  Widget build(BuildContext context) {
    return const FinanceCard(
      child: Text('Set up your Budget to see this month’s plan.'),
    );
  }
}

class _EmptyBudgetCard extends StatelessWidget {
  const _EmptyBudgetCard();

  @override
  Widget build(BuildContext context) {
    return const FinanceCard(
      child: Text('No category activity this month yet.'),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 8,
      ),
      child: const Column(
        children: [
          _UpcomingRow(
            date: 'Tomorrow',
            title: 'Rent',
            amount: 450000,
          ),
          Divider(height: 1),
          _UpcomingRow(
            date: '12 Sep',
            title: 'Electricity',
            amount: 65000,
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final String date;
  final String title;
  final int amount;

  const _UpcomingRow({
    required this.date,
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 19,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          MoneyText(
            amount: amount,
            style: Theme
                .of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;

  const _SectionHeader({
    required this.title,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme
                .of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),

        if (actionText != null)
          Text(
            actionText!,
            style: Theme
                .of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _NavItem(
              icon: Icons.pie_chart_outline_rounded,
              selectedIcon: Icons.pie_chart_rounded,
              label: 'Budget',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),

            const SizedBox(width: 50),

            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              label: 'Transactions',
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            _NavItem(
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view_rounded,
              label: 'More',
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primary
        : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 23,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTransactionSheet extends StatelessWidget {
  const _AddTransactionSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        14,
        22,
        30,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'What do you want to record?',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 22),

            const _TransactionAction(
              icon: Icons.north_east_rounded,
              title: 'Expense',
              subtitle: 'Record money you spent',
            ),

            const SizedBox(height: 10),

            const _TransactionAction(
              icon: Icons.south_west_rounded,
              title: 'Income',
              subtitle: 'Record money you received',
            ),

            const SizedBox(height: 10),

            const _TransactionAction(
              icon: Icons.swap_horiz_rounded,
              title: 'Transfer',
              subtitle: 'Move money between accounts',
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TransactionAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final int index;

  const _PlaceholderPage({
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final titles = {
      1: 'Budget',
      2: 'Transactions',
      3: 'More',
    };

    return Center(
      child: Text(
        titles[index] ?? '',
        style: Theme
            .of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatMonth(DateTime date) {
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
