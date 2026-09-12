import '../domain/models/budget_group_summary.dart';
import '../domain/models/category_budget.dart';
import '../domain/models/category_group.dart';
import '../domain/models/finance_category.dart';
import '../domain/models/finance_transaction.dart';
import '../domain/models/monthly_budget_summary.dart';
import '../domain/models/transaction_line_item.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/transaction_line_item_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/models/budget_allocation.dart';

class BudgetService {
  BudgetService({
    required this.budgetRepository,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.transactionLineItemRepository,
  });

  final BudgetRepository budgetRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final TransactionLineItemRepository transactionLineItemRepository;

  static const String feesCategorySystemKey = 'expense.fees_charges';

  Future<MonthlyBudgetSummary> buildMonth({
    required int year,
    required int month,
  }) async {
    _validateMonth(year: year, month: month);

    final settings = await budgetRepository.getBudgetSettings();

    if (settings == null) {
      throw StateError('Budgeting has not been initialized.');
    }

    final selectedMonthStart = DateTime(year, month);

    final selectedMonthEnd = DateTime(year, month + 1);

    //
    // A month whose END is at or before budgetStartDate contains
    // no part of the Nomi budgeting epoch.
    //
    if (!selectedMonthEnd.isAfter(settings.budgetStartDate)) {
      throw StateError('The selected month is before budgeting began.');
    }

    //
    // Make sure default categories exist before resolving the
    // system fee category.
    //
    await categoryRepository.ensureDefaultsExist();

    final feesCategory = await categoryRepository.getCategoryBySystemKey(
      feesCategorySystemKey,
    );

    if (feesCategory == null) {
      throw StateError('Required Fees & Charges category is missing.');
    }

    final feesGroup = await categoryRepository.getGroup(feesCategory.groupId);

    if (feesGroup == null || feesGroup.type != CategoryType.expense) {
      throw StateError('Fees & Charges must belong to an Expense group.');
    }

    //
    // Get every eligible ledger transaction from the budgeting
    // epoch through the end of the selected month.
    //
    final transactions = await transactionRepository.getTransactionsBetween(
      startInclusive: settings.budgetStartDate,
      endExclusive: selectedMonthEnd,
    );

    //
    // Fetch all Expense line items in ONE query.
    //
    final expenseTransactionIds = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .map((transaction) => transaction.id)
        .toList();

    final allLineItems = await transactionLineItemRepository
        .getLineItemsForTransactions(expenseTransactionIds);

    final lineItemsByTransaction = <int, List<TransactionLineItem>>{};

    for (final item in allLineItems) {
      lineItemsByTransaction
          .putIfAbsent(item.transactionId, () => [])
          .add(item);
    }

    //
    // Assignment state.
    //
    final selectedBudgetMonth = await budgetRepository.getBudgetMonth(
      year: year,
      month: month,
    );

    final List<BudgetAllocation> selectedAllocations =
        selectedBudgetMonth == null
        ? const <BudgetAllocation>[]
        : await budgetRepository.getAllocationsForMonth(selectedBudgetMonth.id);

    final selectedAssignedByCategory = <int, int>{};

    for (final allocation in selectedAllocations) {
      selectedAssignedByCategory.update(
        allocation.categoryId,
        (value) => value + allocation.assignedAmount,
        ifAbsent: () => allocation.assignedAmount,
      );
    }

    //
    // Calculate assignments from earlier months.
    //
    // We intentionally don't create missing BudgetMonths here.
    // Reading a budget should never mutate the database.
    //
    final priorAssignedByCategory = <int, int>{};

    var allocationCursor = DateTime(
      settings.budgetStartDate.year,
      settings.budgetStartDate.month,
    );

    while (allocationCursor.isBefore(selectedMonthStart)) {
      final historicalMonth = await budgetRepository.getBudgetMonth(
        year: allocationCursor.year,
        month: allocationCursor.month,
      );

      if (historicalMonth != null) {
        final allocations = await budgetRepository.getAllocationsForMonth(
          historicalMonth.id,
        );

        for (final allocation in allocations) {
          priorAssignedByCategory.update(
            allocation.categoryId,
            (value) => value + allocation.assignedAmount,
            ifAbsent: () => allocation.assignedAmount,
          );
        }
      }

      allocationCursor = DateTime(
        allocationCursor.year,
        allocationCursor.month + 1,
      );
    }

    //
    // Spending maps.
    //
    final spentBeforeByCategory = <int, int>{};
    final spentThisMonthByCategory = <int, int>{};

    var uncategorizedSpentBefore = 0;
    var uncategorizedSpentThisMonth = 0;

    var grossIncomeThisMonth = 0;
    var cumulativeGrossIncome = 0;

    var feesThisMonth = 0;

    var expensePrincipalThisMonth = 0;

    for (final transaction in transactions) {
      final isSelectedMonth = _belongsToSelectedMonth(
        occurredAt: transaction.occurredAt,
        selectedMonthStart: selectedMonthStart,
        selectedMonthEnd: selectedMonthEnd,
        budgetStartDate: settings.budgetStartDate,
      );

      //
      // INCOME
      //
      // Gross income enters Left to Assign.
      //
      // Fees remain separate spending so:
      //
      // gross income - fee spending = net wealth change.
      //
      if (transaction.type == TransactionType.income) {
        cumulativeGrossIncome += transaction.amount;

        if (isSelectedMonth) {
          grossIncomeThisMonth += transaction.amount;
        }
      }

      //
      // FEES
      //
      // Every transaction type can carry a fee.
      //
      if (transaction.fee > 0) {
        if (isSelectedMonth) {
          feesThisMonth += transaction.fee;

          _addAmount(
            spentThisMonthByCategory,
            feesCategory.id,
            transaction.fee,
          );
        } else {
          _addAmount(spentBeforeByCategory, feesCategory.id, transaction.fee);
        }
      }

      //
      // TRANSFER PRINCIPAL
      //
      // Transfers only change the location of money.
      //
      // Their principal has zero budget impact.
      //
      if (transaction.type == TransactionType.transfer) {
        continue;
      }

      //
      // INCOME PRINCIPAL
      //
      // Already handled above through gross income.
      //
      if (transaction.type == TransactionType.income) {
        continue;
      }

      //
      // EXPENSE PRINCIPAL
      //
      if (isSelectedMonth) {
        expensePrincipalThisMonth += transaction.amount;
      }

      final lineItems =
          lineItemsByTransaction[transaction.id] ??
          const <TransactionLineItem>[];

      //
      // Simple Expense:
      //
      // transaction.categoryId is authoritative.
      //
      if (lineItems.isEmpty) {
        final categoryId = transaction.categoryId;

        if (categoryId == null) {
          if (isSelectedMonth) {
            uncategorizedSpentThisMonth += transaction.amount;
          } else {
            uncategorizedSpentBefore += transaction.amount;
          }

          continue;
        }

        if (isSelectedMonth) {
          _addAmount(spentThisMonthByCategory, categoryId, transaction.amount);
        } else {
          _addAmount(spentBeforeByCategory, categoryId, transaction.amount);
        }

        continue;
      }

      //
      // Itemized Expense:
      //
      // line-item categories are authoritative.
      //
      final lineItemTotal = lineItems.fold<int>(
        0,
        (total, item) => total + item.amount,
      );

      //
      // V1 uses full itemization only.
      //
      if (lineItemTotal != transaction.amount) {
        throw StateError(
          'Transaction ${transaction.id} has '
          'line items totaling $lineItemTotal but '
          'its principal amount is '
          '${transaction.amount}.',
        );
      }

      for (final lineItem in lineItems) {
        if (isSelectedMonth) {
          _addAmount(
            spentThisMonthByCategory,
            lineItem.categoryId,
            lineItem.amount,
          );
        } else {
          _addAmount(
            spentBeforeByCategory,
            lineItem.categoryId,
            lineItem.amount,
          );
        }
      }
    }

    //
    // Build the complete set of categories that should appear.
    //
    // Start with active categories so unused active categories
    // still appear in the budget.
    //
    final activeCategories = await categoryRepository.watchCategories().first;

    final categoriesById = <int, FinanceCategory>{
      for (final category in activeCategories) category.id: category,
    };

    final relevantCategoryIds = <int>{
      ...categoriesById.keys,
      ...priorAssignedByCategory.keys,
      ...selectedAssignedByCategory.keys,
      ...spentBeforeByCategory.keys,
      ...spentThisMonthByCategory.keys,
      feesCategory.id,
    };

    //
    // Recover inactive categories which still have historical
    // allocations, rollover, or spending.
    //
    for (final categoryId in relevantCategoryIds) {
      if (categoriesById.containsKey(categoryId)) {
        continue;
      }

      final category = await categoryRepository.getCategory(categoryId);

      if (category != null) {
        categoriesById[categoryId] = category;
      }
    }

    //
    // Resolve category groups.
    //
    final groupsById = <int, CategoryGroup>{};

    for (final category in categoriesById.values) {
      if (groupsById.containsKey(category.groupId)) {
        continue;
      }

      final group = await categoryRepository.getGroup(category.groupId);

      if (group != null) {
        groupsById[group.id] = group;
      }
    }

    //
    // Build CategoryBudget rows.
    //
    final categoriesByGroup = <int, List<CategoryBudget>>{};

    for (final category in categoriesById.values) {
      final group = groupsById[category.groupId];

      if (group == null) {
        continue;
      }

      //
      // Income categories don't receive budget envelopes.
      //
      if (group.type != CategoryType.expense) {
        continue;
      }

      final startingAssigned = priorAssignedByCategory[category.id] ?? 0;

      final spentBefore = spentBeforeByCategory[category.id] ?? 0;

      final assigned = selectedAssignedByCategory[category.id] ?? 0;

      final spent = spentThisMonthByCategory[category.id] ?? 0;

      final categoryBudget = CategoryBudget(
        categoryId: category.id,
        groupId: category.groupId,
        name: category.name,
        sortOrder: category.sortOrder,
        isActive: category.isActive,
        startingAvailable: startingAssigned - spentBefore,
        assigned: assigned,
        spent: spent,
      );

      //
      // Active categories always appear.
      //
      // Inactive categories appear only if they still matter.
      //
      if (!category.isActive && !categoryBudget.hasActivity) {
        continue;
      }

      categoriesByGroup
          .putIfAbsent(category.groupId, () => [])
          .add(categoryBudget);
    }

    final groupSummaries = <BudgetGroupSummary>[];

    for (final entry in categoriesByGroup.entries) {
      final group = groupsById[entry.key];

      if (group == null) {
        continue;
      }

      final categoryRows = entry.value
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);

          if (order != 0) {
            return order;
          }

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

      groupSummaries.add(
        BudgetGroupSummary(
          groupId: group.id,
          name: group.name,
          sortOrder: group.sortOrder,
          categories: List.unmodifiable(categoryRows),
        ),
      );
    }

    groupSummaries.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);

      if (order != 0) {
        return order;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    //
    // UNCATEGORIZED
    //
    // Uncategorized expenses must still reduce the budget.
    //
    // We expose them as a virtual negative-available category
    // instead of silently losing them from the envelope math.
    //
    if (uncategorizedSpentBefore != 0 || uncategorizedSpentThisMonth != 0) {
      final uncategorized = CategoryBudget(
        categoryId: null,
        groupId: null,
        name: 'Uncategorized',
        sortOrder: 0,
        isActive: true,
        startingAvailable: -uncategorizedSpentBefore,
        assigned: 0,
        spent: uncategorizedSpentThisMonth,
      );

      groupSummaries.add(
        BudgetGroupSummary(
          groupId: null,
          name: 'Uncategorized',
          sortOrder: 999999,
          categories: [uncategorized],
        ),
      );
    }

    final assignedThisMonth = selectedAssignedByCategory.values.fold<int>(
      0,
      (total, value) => total + value,
    );

    final priorAssigned = priorAssignedByCategory.values.fold<int>(
      0,
      (total, value) => total + value,
    );

    final cumulativeAssigned = priorAssigned + assignedThisMonth;

    //
    // Overall spending is:
    //
    // Expense principal
    // +
    // every transaction fee
    //
    // Transfer principal is deliberately excluded.
    //
    final spentThisMonth = expensePrincipalThisMonth + feesThisMonth;

    return MonthlyBudgetSummary(
      year: year,
      month: month,
      budgetStartDate: settings.budgetStartDate,
      initialAssignableAmount: settings.initialAssignableAmount,
      grossIncome: grossIncomeThisMonth,
      cumulativeGrossIncome: cumulativeGrossIncome,
      assigned: assignedThisMonth,
      cumulativeAssigned: cumulativeAssigned,
      spent: spentThisMonth,
      fees: feesThisMonth,
      groups: List.unmodifiable(groupSummaries),
    );
  }

  void _addAmount(Map<int, int> values, int categoryId, int amount) {
    values.update(
      categoryId,
      (existing) => existing + amount,
      ifAbsent: () => amount,
    );
  }

  bool _belongsToSelectedMonth({
    required DateTime occurredAt,
    required DateTime selectedMonthStart,
    required DateTime selectedMonthEnd,
    required DateTime budgetStartDate,
  }) {
    final effectiveMonthStart = selectedMonthStart.isBefore(budgetStartDate)
        ? budgetStartDate
        : selectedMonthStart;

    return !occurredAt.isBefore(effectiveMonthStart) &&
        occurredAt.isBefore(selectedMonthEnd);
  }

  void _validateMonth({required int year, required int month}) {
    if (year < 1) {
      throw ArgumentError('Budget year must be valid.');
    }

    if (month < 1 || month > 12) {
      throw ArgumentError('Budget month must be between 1 and 12.');
    }
  }
}
