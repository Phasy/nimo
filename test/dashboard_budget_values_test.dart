import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/domain/models/category_budget.dart';
import 'package:nomi/domain/models/monthly_budget_summary.dart';

void main() {
  test('dashboard-facing Budget values use the Budget domain semantics', () {
    const category = CategoryBudget(
      categoryId: 1,
      groupId: 1,
      name: 'Groceries',
      sortOrder: 0,
      isActive: true,
      startingAvailable: 30000,
      assigned: 20000,
      spent: 12000,
    );

    final summary = MonthlyBudgetSummary(
      year: 2026,
      month: 9,
      budgetStartDate: DateTime(2026, 9, 1),
      initialAssignableAmount: 100000,
      grossIncome: 50000,
      cumulativeGrossIncome: 50000,
      assigned: 20000,
      cumulativeAssigned: 20000,
      spent: 13000,
      fees: 1000,
      groups: const [],
    );

    expect(category.planningCapacity, 50000);
    expect(category.available, 38000);
    expect(summary.principalSpent, 12000);
    expect(summary.remainingThisMonth, 37000);
    expect(summary.leftToAssign, 130000);
  });
}
