import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/budget_repository_impl.dart';
import '../../../data/repositories/item_repository_impl.dart';
import '../../../data/repositories/transaction_line_item_repository_impl.dart';
import '../../../domain/models/budget_settings.dart';
import '../../../domain/models/category_budget.dart';
import '../../../domain/models/monthly_budget_summary.dart';
import '../../../domain/models/planned_item_funding.dart';
import '../../../domain/repositories/budget_repository.dart';
import '../../../domain/repositories/item_repository.dart';
import '../../../domain/repositories/transaction_line_item_repository.dart';
import '../../../services/budget_service.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../../domain/models/monthly_planned_item.dart';

//
// REPOSITORIES
//

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final database = ref.watch(databaseProvider);

  return DriftBudgetRepository(database);
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final database = ref.watch(databaseProvider);

  return DriftItemRepository(database);
});

final transactionLineItemRepositoryProvider =
    Provider<TransactionLineItemRepository>((ref) {
      final database = ref.watch(databaseProvider);

      return DriftTransactionLineItemRepository(database);
    });

//
// SERVICE
//

final budgetServiceProvider = Provider<BudgetService>((ref) {
  final budgetRepository = ref.watch(budgetRepositoryProvider);

  final categoryRepository = ref.watch(categoryRepositoryProvider);

  final transactionRepository = ref.watch(transactionRepositoryProvider);

  final lineItemRepository = ref.watch(transactionLineItemRepositoryProvider);

  return BudgetService(
    budgetRepository: budgetRepository,
    categoryRepository: categoryRepository,
    transactionRepository: transactionRepository,
    transactionLineItemRepository: lineItemRepository,
  );
});

//
// SETTINGS
//

final budgetSettingsProvider = FutureProvider<BudgetSettings?>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);

  return repository.getBudgetSettings();
});

//
// SELECTED MONTH
//

class SelectedBudgetMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();

    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1);
  }

  void currentMonth() {
    final now = DateTime.now();

    state = DateTime(now.year, now.month);
  }
}

final selectedBudgetMonthProvider =
    NotifierProvider<SelectedBudgetMonthNotifier, DateTime>(
      SelectedBudgetMonthNotifier.new,
    );

//
// MONTHLY BUDGET
//

typedef BudgetPeriod = ({int year, int month});

final monthlyBudgetProvider =
    FutureProvider.family<MonthlyBudgetSummary, BudgetPeriod>((
      ref,
      period,
    ) async {
      //
      // Recalculate automatically when ledger/category data changes.
      //
    ref.watch(transactionsProvider);
    ref.watch(categoriesProvider(null));
    ref.watch(accountsProvider);

      final service = ref.watch(budgetServiceProvider);

      return service.buildMonth(year: period.year, month: period.month);
    });

//
// CURRENTLY SELECTED BUDGET
//

final selectedMonthlyBudgetProvider =
    Provider<AsyncValue<MonthlyBudgetSummary>>((ref) {
      final selectedMonth = ref.watch(selectedBudgetMonthProvider);

      return ref.watch(
        monthlyBudgetProvider((
          year: selectedMonth.year,
          month: selectedMonth.month,
        )),
      );
    });

/// The calendar month's Budget summary used by the Dashboard.
///
/// Null is a deliberate neutral state before Budget initialization.
final currentMonthlyBudgetProvider =
    FutureProvider<MonthlyBudgetSummary?>((ref) async {
      ref.watch(transactionsProvider);
      ref.watch(categoriesProvider(null));
      ref.watch(accountsProvider);

      final settings = await ref.watch(budgetSettingsProvider.future);

      if (settings == null) {
        return null;
      }

      final now = DateTime.now();
      return ref.watch(
        monthlyBudgetProvider((year: now.year, month: now.month)).future,
      );
    });

//
// ALLOCATION ACTIONS
//

class BudgetAllocationController extends Notifier<void> {
  @override
  void build() {}

  Future<void> setAllocation({
    required int year,
    required int month,
    required int categoryId,
    required int assignedAmount,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);

    //
    // Reading a month doesn't create it, but assigning money does.
    //
    final budgetMonth = await repository.getOrCreateBudgetMonth(
      year: year,
      month: month,
    );

    await repository.setAllocation(
      budgetMonthId: budgetMonth.id,
      categoryId: categoryId,
      assignedAmount: assignedAmount,
    );

    //
    // Force calculation to run again immediately.
    //
    ref.invalidate(monthlyBudgetProvider((year: year, month: month)));
  }

  Future<void> removeAllocation({
    required int year,
    required int month,
    required int categoryId,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);

    final budgetMonth = await repository.getBudgetMonth(
      year: year,
      month: month,
    );

    if (budgetMonth == null) {
      return;
    }

    await repository.removeAllocation(
      budgetMonthId: budgetMonth.id,
      categoryId: categoryId,
    );

    ref.invalidate(monthlyBudgetProvider((year: year, month: month)));
  }
}

final budgetAllocationControllerProvider =
    NotifierProvider<BudgetAllocationController, void>(
      BudgetAllocationController.new,
    );

//
// INITIALIZATION
//

final budgetInitializationProvider = FutureProvider<BudgetSettings>((
  ref,
) async {
  final budgetRepository = ref.watch(budgetRepositoryProvider);

  final existing = await budgetRepository.getBudgetSettings();

  if (existing != null) {
    return existing;
  }

  //
  // Budgeting begins with money Nomi currently knows we own.
  //
  final accounts = await ref.watch(accountsProvider.future);

  final totalOwned = accounts.fold<int>(
    0,
    (total, account) => total + account.currentBalance,
  );

  final now = DateTime.now();

  final settings = await budgetRepository.initializeBudget(
    budgetStartDate: now,
    initialAssignableAmount: totalOwned,
  );

  await budgetRepository.getOrCreateBudgetMonth(
    year: now.year,
    month: now.month,
  );

  ref.invalidate(budgetSettingsProvider);

  return settings;
});

typedef PlannedItemsQuery = ({int year, int month, int categoryId});

final plannedItemsProvider =
    StreamProvider.family<List<MonthlyPlannedItem>, PlannedItemsQuery>((
      ref,
      query,
    ) async* {
      final repository = ref.watch(budgetRepositoryProvider);

      final budgetMonth = await repository.getBudgetMonth(
        year: query.year,
        month: query.month,
      );

      if (budgetMonth == null) {
        yield const <MonthlyPlannedItem>[];
        return;
      }

      yield* repository.watchPlannedItemsForCategory(
        budgetMonthId: budgetMonth.id,
        categoryId: query.categoryId,
      );
    });

class PlannedItemController extends Notifier<void> {
  @override
  void build() {}

  Future<PlannedItemFundingAssessment> assessFunding({
    required int year,
    required int month,
    required int categoryId,
    required int? proposedPlannedAmount,
    int? editedItemId,
  }) {
    return _assessFunding(
      year: year,
      month: month,
      categoryId: categoryId,
      proposedPlannedAmount: proposedPlannedAmount,
      editedItemId: editedItemId,
    );
  }

  Future<void> createItem({
    required int year,
    required int month,
    required int categoryId,
    required String name,
    int? plannedQuantity,
    String? unit,
    int? plannedAmount,
    String? note,
    bool increaseAllocation = false,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);

    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }

    _validatePlannedValues(
      plannedQuantity: plannedQuantity,
      plannedAmount: plannedAmount,
    );

    final database = ref.read(databaseProvider);

    await database.transaction(() async {
      final assessment = await _assessFunding(
        year: year,
        month: month,
        categoryId: categoryId,
        proposedPlannedAmount: plannedAmount,
      );

      final budgetMonth = await repository.getOrCreateBudgetMonth(
        year: year,
        month: month,
      );

      final existing = await repository.getPlannedItemsForCategory(
        budgetMonthId: budgetMonth.id,
        categoryId: categoryId,
      );

      await repository.createPlannedItem(
        budgetMonthId: budgetMonth.id,
        categoryId: categoryId,
        nameSnapshot: trimmedName,
        plannedQuantity: plannedQuantity,
        unitSnapshot: _cleanOptionalText(unit),
        plannedAmount: plannedAmount,
        sortOrder: existing.length,
        note: _cleanOptionalText(note),
      );

      if (increaseAllocation && assessment.needsAdditionalFunding) {
        await ref
            .read(budgetAllocationControllerProvider.notifier)
            .setAllocation(
              year: year,
              month: month,
              categoryId: categoryId,
              assignedAmount: assessment.assignedAfterIncrease,
            );
      }
    });

    _invalidateMonth(year: year, month: month);
  }

  Future<void> updateItem({
    required int year,
    required int month,
    required MonthlyPlannedItem item,
    required String name,
    int? plannedQuantity,
    String? unit,
    int? plannedAmount,
    String? note,
    bool increaseAllocation = false,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);

    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }

    _validatePlannedValues(
      plannedQuantity: plannedQuantity,
      plannedAmount: plannedAmount,
    );

    final cleanedUnit = _cleanOptionalText(unit);

    final cleanedNote = _cleanOptionalText(note);

    final updated = item.copyWith(
      nameSnapshot: trimmedName,

      plannedQuantity: plannedQuantity,
      clearPlannedQuantity: plannedQuantity == null,

      unitSnapshot: cleanedUnit,
      clearUnitSnapshot: cleanedUnit == null,

      plannedAmount: plannedAmount,
      clearPlannedAmount: plannedAmount == null,

      note: cleanedNote,
      clearNote: cleanedNote == null,

      updatedAt: DateTime.now(),
    );

    final database = ref.read(databaseProvider);

    await database.transaction(() async {
      final assessment = await _assessFunding(
        year: year,
        month: month,
        categoryId: item.categoryId,
        proposedPlannedAmount: plannedAmount,
        editedItemId: item.id,
      );

      await repository.updatePlannedItem(updated);

      if (increaseAllocation && assessment.needsAdditionalFunding) {
        await ref
            .read(budgetAllocationControllerProvider.notifier)
            .setAllocation(
              year: year,
              month: month,
              categoryId: item.categoryId,
              assignedAmount: assessment.assignedAfterIncrease,
            );
      }
    });

    _invalidateMonth(year: year, month: month);
  }

  Future<PlannedItemFundingAssessment> _assessFunding({
    required int year,
    required int month,
    required int categoryId,
    required int? proposedPlannedAmount,
    int? editedItemId,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);
    final summary = await ref
        .read(budgetServiceProvider)
        .buildMonth(year: year, month: month);

    CategoryBudget? category;

    for (final candidate in summary.categories) {
      if (candidate.categoryId == categoryId) {
        category = candidate;
        break;
      }
    }

    if (category == null) {
      throw StateError('Budget category could not be found.');
    }

    final budgetMonth = await repository.getBudgetMonth(
      year: year,
      month: month,
    );

    final items = budgetMonth == null
        ? const <MonthlyPlannedItem>[]
        : await repository.getPlannedItemsForCategory(
            budgetMonthId: budgetMonth.id,
            categoryId: categoryId,
          );

    return PlannedItemFundingCalculator.assess(
      existingItems: items,
      editedItemId: editedItemId,
      proposedPlannedAmount: proposedPlannedAmount,
      startingAvailable: category.startingAvailable,
      assigned: category.assigned,
    );
  }

  void _invalidateMonth({required int year, required int month}) {
    ref.invalidate(monthlyBudgetProvider((year: year, month: month)));
  }

  Future<void> setCompleted({
    required MonthlyPlannedItem item,
    required bool completed,
  }) async {
    final repository = ref.read(budgetRepositoryProvider);

    await repository.updatePlannedItem(
      item.copyWith(isCompleted: completed, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteItem(MonthlyPlannedItem item) async {
    final repository = ref.read(budgetRepositoryProvider);

    await repository.deletePlannedItem(item.id);
  }
}

final plannedItemControllerProvider =
    NotifierProvider<PlannedItemController, void>(PlannedItemController.new);

String? _cleanOptionalText(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();

  return trimmed.isEmpty ? null : trimmed;
}

void _validatePlannedValues({
  required int? plannedQuantity,
  required int? plannedAmount,
}) {
  if (plannedQuantity != null && plannedQuantity <= 0) {
    throw ArgumentError('Planned quantity must be greater than zero.');
  }

  if (plannedAmount != null && plannedAmount < 0) {
    throw ArgumentError('Planned amount cannot be negative.');
  }
}
