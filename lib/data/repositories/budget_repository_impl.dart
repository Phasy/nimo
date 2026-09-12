import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/budget_allocation.dart' as domain;
import '../../domain/models/budget_month.dart' as domain;
import '../../domain/models/budget_settings.dart' as domain;
import '../../domain/models/monthly_planned_item.dart' as domain;
import '../../domain/repositories/budget_repository.dart';

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);

  final AppDatabase _db;

  //
  // BUDGET SETTINGS
  //

  @override
  Future<domain.BudgetSettings?> getBudgetSettings() async {
    final query = _db.select(_db.budgetSettings)
      ..orderBy([(table) => OrderingTerm.asc(table.id)])
      ..limit(1);

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapBudgetSettings(row);
  }

  @override
  Future<domain.BudgetSettings> initializeBudget({
    required DateTime budgetStartDate,
    required int initialAssignableAmount,
  }) async {
    if (initialAssignableAmount < 0) {
      throw ArgumentError('Initial assignable amount cannot be negative.');
    }

    return _db.transaction(() async {
      final existing = await getBudgetSettings();

      if (existing != null) {
        return existing;
      }

      final id = await _db
          .into(_db.budgetSettings)
          .insert(
            BudgetSettingsCompanion.insert(
              budgetStartDate: budgetStartDate,
              initialAssignableAmount: initialAssignableAmount,
            ),
          );

      final query = _db.select(_db.budgetSettings)
        ..where((table) => table.id.equals(id));

      final row = await query.getSingle();

      return _mapBudgetSettings(row);
    });
  }

  @override
  Future<void> updateInitialAssignableAmount({required int delta}) async {
    await _db.transaction(() async {
      final settings = await getBudgetSettings();

      if (settings == null) {
        throw StateError('Budgeting has not been initialized.');
      }

      final newAmount = settings.initialAssignableAmount + delta;

      if (newAmount < 0) {
        throw StateError('Initial assignable amount cannot become negative.');
      }

      await (_db.update(
        _db.budgetSettings,
      )..where((table) => table.id.equals(settings.id))).write(
        BudgetSettingsCompanion(
          initialAssignableAmount: Value(newAmount),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  //
  // BUDGET MONTHS
  //

  @override
  Future<domain.BudgetMonth?> getBudgetMonth({
    required int year,
    required int month,
  }) async {
    _validateMonth(year, month);

    final query = _db.select(_db.budgetMonths)
      ..where((table) => table.year.equals(year) & table.month.equals(month));

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapBudgetMonth(row);
  }

  @override
  Future<domain.BudgetMonth> getOrCreateBudgetMonth({
    required int year,
    required int month,
  }) async {
    _validateMonth(year, month);

    final existing = await getBudgetMonth(year: year, month: month);

    if (existing != null) {
      return existing;
    }

    await _db
        .into(_db.budgetMonths)
        .insert(
          BudgetMonthsCompanion.insert(year: year, month: month),
          mode: InsertMode.insertOrIgnore,
        );

    final created = await getBudgetMonth(year: year, month: month);

    if (created == null) {
      throw StateError('Unable to create budget month $year-$month.');
    }

    return created;
  }

  //
  // ALLOCATIONS
  //

  @override
  Stream<List<domain.BudgetAllocation>> watchAllocationsForMonth(
    int budgetMonthId,
  ) {
    final query = _db.select(_db.budgetAllocations)
      ..where((table) => table.budgetMonthId.equals(budgetMonthId))
      ..orderBy([(table) => OrderingTerm.asc(table.categoryId)]);

    return query.watch().map((rows) => rows.map(_mapBudgetAllocation).toList());
  }

  @override
  Future<List<domain.BudgetAllocation>> getAllocationsForMonth(
    int budgetMonthId,
  ) async {
    final query = _db.select(_db.budgetAllocations)
      ..where((table) => table.budgetMonthId.equals(budgetMonthId))
      ..orderBy([(table) => OrderingTerm.asc(table.categoryId)]);

    final rows = await query.get();

    return rows.map(_mapBudgetAllocation).toList();
  }

  @override
  Future<domain.BudgetAllocation?> getAllocation({
    required int budgetMonthId,
    required int categoryId,
  }) async {
    final query = _db.select(_db.budgetAllocations)
      ..where(
        (table) =>
            table.budgetMonthId.equals(budgetMonthId) &
            table.categoryId.equals(categoryId),
      );

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapBudgetAllocation(row);
  }

  @override
  Future<void> setAllocation({
    required int budgetMonthId,
    required int categoryId,
    required int assignedAmount,
  }) async {
    final existing = await getAllocation(
      budgetMonthId: budgetMonthId,
      categoryId: categoryId,
    );

    if (existing == null) {
      await _db
          .into(_db.budgetAllocations)
          .insert(
            BudgetAllocationsCompanion.insert(
              budgetMonthId: budgetMonthId,
              categoryId: categoryId,
              assignedAmount: assignedAmount,
            ),
          );

      return;
    }

    await (_db.update(
      _db.budgetAllocations,
    )..where((table) => table.id.equals(existing.id))).write(
      BudgetAllocationsCompanion(
        assignedAmount: Value(assignedAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> removeAllocation({
    required int budgetMonthId,
    required int categoryId,
  }) async {
    await (_db.delete(_db.budgetAllocations)..where(
          (table) =>
              table.budgetMonthId.equals(budgetMonthId) &
              table.categoryId.equals(categoryId),
        ))
        .go();
  }

  @override
  Future<int> sumAssignmentsThroughMonth({
    required int year,
    required int month,
  }) async {
    _validateMonth(year, month);

    final total = _db.budgetAllocations.assignedAmount.sum();

    final query = _db.selectOnly(_db.budgetAllocations)
      ..addColumns([total])
      ..join([
        innerJoin(
          _db.budgetMonths,
          _db.budgetMonths.id.equalsExp(_db.budgetAllocations.budgetMonthId),
        ),
      ])
      ..where(_isMonthBeforeOrEqual(year, month));

    final row = await query.getSingle();

    return row.read(total) ?? 0;
  }

  @override
  Future<int> sumAssignmentsBeforeMonth({
    required int year,
    required int month,
  }) async {
    _validateMonth(year, month);

    final total = _db.budgetAllocations.assignedAmount.sum();

    final query = _db.selectOnly(_db.budgetAllocations)
      ..addColumns([total])
      ..join([
        innerJoin(
          _db.budgetMonths,
          _db.budgetMonths.id.equalsExp(_db.budgetAllocations.budgetMonthId),
        ),
      ])
      ..where(_isMonthBefore(year, month));

    final row = await query.getSingle();

    return row.read(total) ?? 0;
  }

  //
  // PLANNED ITEMS
  //

  @override
  Stream<List<domain.MonthlyPlannedItem>> watchPlannedItemsForMonth(
    int budgetMonthId,
  ) {
    final query = _db.select(_db.monthlyPlannedItems)
      ..where((table) => table.budgetMonthId.equals(budgetMonthId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.categoryId),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapMonthlyPlannedItem).toList(),
    );
  }

  @override
  Stream<List<domain.MonthlyPlannedItem>> watchPlannedItemsForCategory({
    required int budgetMonthId,
    required int categoryId,
  }) {
    final query = _db.select(_db.monthlyPlannedItems)
      ..where(
        (table) =>
            table.budgetMonthId.equals(budgetMonthId) &
            table.categoryId.equals(categoryId),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapMonthlyPlannedItem).toList(),
    );
  }

  @override
  Future<List<domain.MonthlyPlannedItem>> getPlannedItemsForCategory({
    required int budgetMonthId,
    required int categoryId,
  }) async {
    final query = _db.select(_db.monthlyPlannedItems)
      ..where(
        (table) =>
            table.budgetMonthId.equals(budgetMonthId) &
            table.categoryId.equals(categoryId),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);

    final rows = await query.get();
    return rows.map(_mapMonthlyPlannedItem).toList();
  }

  @override
  Future<domain.MonthlyPlannedItem?> getPlannedItem(int id) async {
    final query = _db.select(_db.monthlyPlannedItems)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapMonthlyPlannedItem(row);
  }

  @override
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
  }) {
    final cleanedName = nameSnapshot.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Planned item name cannot be empty.');
    }

    if (plannedQuantity != null && plannedQuantity <= 0) {
      throw ArgumentError('Planned quantity must be greater than zero.');
    }

    if (plannedAmount != null && plannedAmount < 0) {
      throw ArgumentError('Planned amount cannot be negative.');
    }

    return _db
        .into(_db.monthlyPlannedItems)
        .insert(
          MonthlyPlannedItemsCompanion.insert(
            budgetMonthId: budgetMonthId,
            categoryId: categoryId,
            itemDefinitionId: Value(itemDefinitionId),
            nameSnapshot: cleanedName,
            plannedQuantity: Value(plannedQuantity),
            unitSnapshot: Value(_cleanOptionalText(unitSnapshot)),
            plannedAmount: Value(plannedAmount),
            isCompleted: Value(isCompleted),
            sortOrder: Value(sortOrder),
            note: Value(_cleanOptionalText(note)),
          ),
        );
  }

  @override
  Future<void> updatePlannedItem(domain.MonthlyPlannedItem item) async {
    final cleanedName = item.nameSnapshot.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Planned item name cannot be empty.');
    }

    if (item.plannedQuantity != null && item.plannedQuantity! <= 0) {
      throw ArgumentError('Planned quantity must be greater than zero.');
    }

    if (item.plannedAmount != null && item.plannedAmount! < 0) {
      throw ArgumentError('Planned amount cannot be negative.');
    }

    await (_db.update(
      _db.monthlyPlannedItems,
    )..where((table) => table.id.equals(item.id))).write(
      MonthlyPlannedItemsCompanion(
        budgetMonthId: Value(item.budgetMonthId),
        categoryId: Value(item.categoryId),
        itemDefinitionId: Value(item.itemDefinitionId),
        nameSnapshot: Value(cleanedName),
        plannedQuantity: Value(item.plannedQuantity),
        unitSnapshot: Value(_cleanOptionalText(item.unitSnapshot)),
        plannedAmount: Value(item.plannedAmount),
        isCompleted: Value(item.isCompleted),
        sortOrder: Value(item.sortOrder),
        note: Value(_cleanOptionalText(item.note)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deletePlannedItem(int id) async {
    await _db.transaction(() async {
      //
      // Preserve real purchase history.
      //
      // A transaction line item may have been linked to this
      // monthly plan. Deleting the PLAN should not delete or
      // invalidate the actual purchase.
      //
      await (_db.update(
        _db.transactionLineItems,
      )..where((table) => table.monthlyPlannedItemId.equals(id))).write(
        TransactionLineItemsCompanion(
          monthlyPlannedItemId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (_db.delete(
        _db.monthlyPlannedItems,
      )..where((table) => table.id.equals(id))).go();
    });
  }

  @override
  Future<void> reorderPlannedItems({
    required int budgetMonthId,
    required int categoryId,
    required List<int> orderedItemIds,
  }) async {
    await _db.transaction(() async {
      for (var index = 0; index < orderedItemIds.length; index++) {
        final itemId = orderedItemIds[index];

        await (_db.update(_db.monthlyPlannedItems)..where(
              (table) =>
                  table.id.equals(itemId) &
                  table.budgetMonthId.equals(budgetMonthId) &
                  table.categoryId.equals(categoryId),
            ))
            .write(
              MonthlyPlannedItemsCompanion(
                sortOrder: Value(index),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });
  }

  //
  // QUERY HELPERS
  //

  Expression<bool> _isMonthBeforeOrEqual(int year, int month) {
    return _db.budgetMonths.year.isSmallerThanValue(year) |
        (_db.budgetMonths.year.equals(year) &
            _db.budgetMonths.month.isSmallerOrEqualValue(month));
  }

  Expression<bool> _isMonthBefore(int year, int month) {
    return _db.budgetMonths.year.isSmallerThanValue(year) |
        (_db.budgetMonths.year.equals(year) &
            _db.budgetMonths.month.isSmallerThanValue(month));
  }

  void _validateMonth(int year, int month) {
    if (year < 1) {
      throw ArgumentError('Budget year must be valid.');
    }

    if (month < 1 || month > 12) {
      throw ArgumentError('Budget month must be between 1 and 12.');
    }
  }

  String? _cleanOptionalText(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  //
  // MAPPERS
  //

  domain.BudgetSettings _mapBudgetSettings(BudgetSetting row) {
    return domain.BudgetSettings(
      id: row.id,
      budgetStartDate: row.budgetStartDate,
      initialAssignableAmount: row.initialAssignableAmount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  domain.BudgetMonth _mapBudgetMonth(BudgetMonth row) {
    return domain.BudgetMonth(
      id: row.id,
      year: row.year,
      month: row.month,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  domain.BudgetAllocation _mapBudgetAllocation(BudgetAllocation row) {
    return domain.BudgetAllocation(
      id: row.id,
      budgetMonthId: row.budgetMonthId,
      categoryId: row.categoryId,
      assignedAmount: row.assignedAmount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  domain.MonthlyPlannedItem _mapMonthlyPlannedItem(MonthlyPlannedItem row) {
    return domain.MonthlyPlannedItem(
      id: row.id,
      budgetMonthId: row.budgetMonthId,
      categoryId: row.categoryId,
      itemDefinitionId: row.itemDefinitionId,
      nameSnapshot: row.nameSnapshot,
      plannedQuantity: row.plannedQuantity,
      unitSnapshot: row.unitSnapshot,
      plannedAmount: row.plannedAmount,
      isCompleted: row.isCompleted,
      sortOrder: row.sortOrder,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
