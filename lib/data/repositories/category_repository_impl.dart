import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/category_group.dart' as category_domain;
import '../../domain/models/finance_category.dart' as finance_domain;
import '../../domain/repositories/category_repository.dart';
import '../seeds/default_categories.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<category_domain.CategoryGroup>> watchGroups({
    category_domain.CategoryType? type,
  }) {
    final query = _db.select(_db.categoryGroups)
      ..where((table) => table.isActive.equals(true))
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.name),
      ]);

    if (type != null) {
      query.where((table) => table.type.equals(type.name));
    }

    return query.watch().map((rows) => rows.map(_mapGroup).toList());
  }

  @override
  Stream<List<finance_domain.FinanceCategory>> watchCategories({int? groupId}) {
    final query = _db.select(_db.categories)
      ..where((table) => table.isActive.equals(true))
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.name),
      ]);

    if (groupId != null) {
      query.where((table) => table.groupId.equals(groupId));
    }

    return query.watch().map((rows) => rows.map(_mapCategory).toList());
  }

  @override
  Future<category_domain.CategoryGroup?> getGroup(int id) async {
    final query = _db.select(_db.categoryGroups)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapGroup(row);
  }

  @override
  Future<finance_domain.FinanceCategory?> getCategory(int id) async {
    final query = _db.select(_db.categories)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapCategory(row);
  }

  @override
  Future<int> createGroup({
    required String name,
    required category_domain.CategoryType type,
    String? systemKey,
    required int sortOrder,
  }) {
    return _db
        .into(_db.categoryGroups)
        .insert(
          CategoryGroupsCompanion.insert(
            name: name.trim(),
            type: type.name,
            systemKey: Value(systemKey),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  @override
  Future<int> createCategory({
    required int groupId,
    required String name,
    String? systemKey,
    required int sortOrder,
  }) {
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            groupId: groupId,
            name: name.trim(),
            systemKey: Value(systemKey),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  @override
  Future<void> updateGroup(category_domain.CategoryGroup group) async {
    await (_db.update(
      _db.categoryGroups,
    )..where((table) => table.id.equals(group.id))).write(
      CategoryGroupsCompanion(
        name: Value(group.name.trim()),
        type: Value(group.type.name),
        systemKey: Value(group.systemKey),
        sortOrder: Value(group.sortOrder),
        isActive: Value(group.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateCategory(finance_domain.FinanceCategory category) async {
    await (_db.update(
      _db.categories,
    )..where((table) => table.id.equals(category.id))).write(
      CategoriesCompanion(
        groupId: Value(category.groupId),
        name: Value(category.name.trim()),
        systemKey: Value(category.systemKey),
        sortOrder: Value(category.sortOrder),
        isActive: Value(category.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deactivateGroup(int id) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.categoryGroups,
      )..where((table) => table.id.equals(id))).write(
        CategoryGroupsCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (_db.update(
        _db.categories,
      )..where((table) => table.groupId.equals(id))).write(
        CategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> deactivateCategory(int id) async {
    await (_db.update(
      _db.categories,
    )..where((table) => table.id.equals(id))).write(
      CategoriesCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> reorderGroups(List<int> orderedGroupIds) async {
    await _db.transaction(() async {
      for (var index = 0; index < orderedGroupIds.length; index++) {
        final groupId = orderedGroupIds[index];

        await (_db.update(
          _db.categoryGroups,
        )..where((table) => table.id.equals(groupId))).write(
          CategoryGroupsCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  @override
  Future<void> reorderCategories(
    int groupId,
    List<int> orderedCategoryIds,
  ) async {
    await _db.transaction(() async {
      for (var index = 0; index < orderedCategoryIds.length; index++) {
        final categoryId = orderedCategoryIds[index];

        await (_db.update(_db.categories)..where(
              (table) =>
                  table.id.equals(categoryId) & table.groupId.equals(groupId),
            ))
            .write(
              CategoriesCompanion(
                sortOrder: Value(index),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });
  }

  @override
  Future<void> ensureDefaultsExist() async {
    await _db.transaction(() async {
      for (final groupSeed in defaultCategoryGroups) {
        final existingGroupQuery = _db.select(_db.categoryGroups)
          ..where((table) => table.systemKey.equals(groupSeed.systemKey));

        var groupRow = await existingGroupQuery.getSingleOrNull();

        int groupId;

        if (groupRow == null) {
          groupId = await _db
              .into(_db.categoryGroups)
              .insert(
                CategoryGroupsCompanion.insert(
                  name: groupSeed.name,
                  type: groupSeed.type.name,
                  systemKey: Value(groupSeed.systemKey),
                  sortOrder: Value(groupSeed.sortOrder),
                ),
              );
        } else {
          groupId = groupRow.id;
        }

        for (final categorySeed in groupSeed.categories) {
          final existingCategoryQuery = _db.select(_db.categories)
            ..where((table) => table.systemKey.equals(categorySeed.systemKey));

          final existingCategory = await existingCategoryQuery
              .getSingleOrNull();

          if (existingCategory == null) {
            await _db
                .into(_db.categories)
                .insert(
                  CategoriesCompanion.insert(
                    groupId: groupId,
                    name: categorySeed.name,
                    systemKey: Value(categorySeed.systemKey),
                    sortOrder: Value(categorySeed.sortOrder),
                  ),
                );
          }
        }
      }
    });
  }

  @override
  Future<bool> groupNameExists({
    required String name,
    required category_domain.CategoryType type,
    int? excludingGroupId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final query = _db.select(_db.categoryGroups)
      ..where(
        (table) =>
            table.type.equals(type.name) &
            table.isActive.equals(true) &
            table.name.lower().equals(normalizedName),
      );

    if (excludingGroupId != null) {
      query.where((table) => table.id.equals(excludingGroupId).not());
    }

    final existing = await query.getSingleOrNull();

    return existing != null;
  }

  @override
  Future<bool> categoryNameExists({
    required String name,
    required int groupId,
    int? excludingCategoryId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final query = _db.select(_db.categories)
      ..where(
        (table) =>
            table.groupId.equals(groupId) &
            table.isActive.equals(true) &
            table.name.lower().equals(normalizedName),
      );

    if (excludingCategoryId != null) {
      query.where((table) => table.id.equals(excludingCategoryId).not());
    }

    final existing = await query.getSingleOrNull();

    return existing != null;
  }

  @override
  Future<void> moveCategory({
    required finance_domain.FinanceCategory category,
    required int newGroupId,
    required String name,
  }) async {
    await _db.transaction(() async {
      final destinationQuery = _db.select(_db.categories)
        ..where(
          (table) =>
              table.groupId.equals(newGroupId) & table.isActive.equals(true),
        )
        ..orderBy([(table) => OrderingTerm.desc(table.sortOrder)])
        ..limit(1);

      final lastCategory = await destinationQuery.getSingleOrNull();

      final nextSortOrder = lastCategory == null
          ? 0
          : lastCategory.sortOrder + 1;

      await (_db.update(
        _db.categories,
      )..where((table) => table.id.equals(category.id))).write(
        CategoriesCompanion(
          groupId: Value(newGroupId),
          name: Value(name.trim()),
          sortOrder: Value(nextSortOrder),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<finance_domain.FinanceCategory?> getCategoryBySystemKey(
    String systemKey,
  ) async {
    final query = _db.select(_db.categories)
      ..where((table) => table.systemKey.equals(systemKey));

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapCategory(row);
  }

  category_domain.CategoryGroup _mapGroup(CategoryGroup row) {
    return category_domain.CategoryGroup(
      id: row.id,
      name: row.name,
      type: category_domain.CategoryType.values.byName(row.type),
      systemKey: row.systemKey,
      sortOrder: row.sortOrder,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  finance_domain.FinanceCategory _mapCategory(Category row) {
    return finance_domain.FinanceCategory(
      id: row.id,
      groupId: row.groupId,
      name: row.name,
      systemKey: row.systemKey,
      sortOrder: row.sortOrder,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
