import 'budget_group_summary.dart';
import 'category_budget.dart';

class MonthlyBudgetSummary {
  const MonthlyBudgetSummary({
    required this.year,
    required this.month,
    required this.budgetStartDate,
    required this.initialAssignableAmount,
    required this.grossIncome,
    required this.cumulativeGrossIncome,
    required this.assigned,
    required this.cumulativeAssigned,
    required this.spent,
    required this.fees,
    required this.groups,
  });

  final int year;
  final int month;

  final DateTime budgetStartDate;

  /// Owned money available when budgeting was first initialized.
  final int initialAssignableAmount;

  /// Gross income recorded inside the selected month.
  ///
  /// Fees do not reduce this value. They are budget spending.
  final int grossIncome;

  /// Gross income from budget start through the selected month.
  final int cumulativeGrossIncome;

  /// Net assignments made in the selected month.
  final int assigned;

  /// Net assignments from budget start through the selected month.
  final int cumulativeAssigned;

  /// Actual spending during the selected month.
  ///
  /// Includes:
  /// - Expense principal
  /// - Income fees
  /// - Expense fees
  /// - Transfer fees
  ///
  /// Excludes transfer principal.
  final int spent;

  /// Fees incurred during the selected month.
  final int fees;

  final List<BudgetGroupSummary> groups;

  DateTime get monthStart => DateTime(year, month);

  DateTime get nextMonthStart =>
      DateTime(year, month + 1);

  /// Money that has entered the budget but has not yet been assigned
  /// a category job.
  int get leftToAssign =>
      initialAssignableAmount +
          cumulativeGrossIncome -
          cumulativeAssigned;

  int get totalAvailable {
    return groups.fold(
      0,
          (total, group) => total + group.available,
    );
  }

  int get totalStartingAvailable {
    return groups.fold(
      0,
          (total, group) =>
      total + group.startingAvailable,
    );
  }

  bool get isFullyAssigned => leftToAssign == 0;

  bool get isOverAssigned => leftToAssign < 0;

  /// Expense principal excluding separately displayed transaction fees.
  int get principalSpent => spent - fees;

  /// Current-month income remaining after all current-month spending.
  int get remainingThisMonth => grossIncome - spent;

  bool get hasOverspending {
    return groups.any(
          (group) => group.hasOverspending,
    );
  }

  Iterable<CategoryBudget> get categories sync* {
    for (final group in groups) {
      yield* group.categories;
    }
  }
}
