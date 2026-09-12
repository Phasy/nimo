import '../models/budget_allocation.dart';
import '../models/budget_month.dart';
import '../models/budget_settings.dart';
import '../models/monthly_planned_item.dart';

abstract class BudgetRepository {
  Future<BudgetSettings?> getBudgetSettings();

  Future<BudgetSettings> initializeBudget({
    required DateTime budgetStartDate,
    required int initialAssignableAmount,
  });

  Future<void> updateInitialAssignableAmount({required int delta});

  Future<BudgetMonth?> getBudgetMonth({required int year, required int month});

  Future<BudgetMonth> getOrCreateBudgetMonth({
    required int year,
    required int month,
  });

  Stream<List<BudgetAllocation>> watchAllocationsForMonth(int budgetMonthId);

  Future<List<BudgetAllocation>> getAllocationsForMonth(int budgetMonthId);

  Future<BudgetAllocation?> getAllocation({
    required int budgetMonthId,
    required int categoryId,
  });

  Future<void> setAllocation({
    required int budgetMonthId,
    required int categoryId,
    required int assignedAmount,
  });

  Future<void> removeAllocation({
    required int budgetMonthId,
    required int categoryId,
  });

  Future<int> sumAssignmentsThroughMonth({
    required int year,
    required int month,
  });

  Future<int> sumAssignmentsBeforeMonth({
    required int year,
    required int month,
  });

  Stream<List<MonthlyPlannedItem>> watchPlannedItemsForMonth(int budgetMonthId);

  Stream<List<MonthlyPlannedItem>> watchPlannedItemsForCategory({
    required int budgetMonthId,
    required int categoryId,
  });

  Future<List<MonthlyPlannedItem>> getPlannedItemsForCategory({
    required int budgetMonthId,
    required int categoryId,
  });

  Future<MonthlyPlannedItem?> getPlannedItem(int id);

  Future<int> createPlannedItem({
    required int budgetMonthId,
    required int categoryId,
    int? itemDefinitionId,
    required String nameSnapshot,
    int? plannedQuantity,
    String? unitSnapshot,
    int? plannedAmount,
    bool isCompleted = false,
    required int sortOrder,
    String? note,
  });

  Future<void> updatePlannedItem(MonthlyPlannedItem item);

  Future<void> deletePlannedItem(int id);

  Future<void> reorderPlannedItems({
    required int budgetMonthId,
    required int categoryId,
    required List<int> orderedItemIds,
  });
}
