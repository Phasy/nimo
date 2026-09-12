import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/item_definition.dart'
as domain;
import '../../domain/repositories/item_repository.dart';

class DriftItemRepository implements ItemRepository {
  DriftItemRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.ItemDefinition>> watchItems({
    int? defaultCategoryId,
  }) {
    final query = _db.select(_db.itemDefinitions)
      ..where(
            (table) => table.isActive.equals(true),
      )
      ..orderBy([
            (table) => OrderingTerm.asc(table.name),
      ]);

    if (defaultCategoryId != null) {
      query.where(
            (table) => table.defaultCategoryId.equals(
          defaultCategoryId,
        ),
      );
    }

    return query.watch().map(
          (rows) =>
          rows.map(_mapItemDefinition).toList(),
    );
  }

  @override
  Future<List<domain.ItemDefinition>> getItems({
    int? defaultCategoryId,
  }) async {
    final query = _db.select(_db.itemDefinitions)
      ..where(
            (table) => table.isActive.equals(true),
      )
      ..orderBy([
            (table) => OrderingTerm.asc(table.name),
      ]);

    if (defaultCategoryId != null) {
      query.where(
            (table) => table.defaultCategoryId.equals(
          defaultCategoryId,
        ),
      );
    }

    final rows = await query.get();

    return rows.map(_mapItemDefinition).toList();
  }

  @override
  Future<domain.ItemDefinition?> getItem(
      int id,
      ) async {
    final query = _db.select(_db.itemDefinitions)
      ..where(
            (table) => table.id.equals(id),
      );

    final row = await query.getSingleOrNull();

    return row == null
        ? null
        : _mapItemDefinition(row);
  }

  @override
  Future<int> createItem({
    required String name,
    int? defaultCategoryId,
    String? defaultUnit,
  }) {
    final cleanedName = name.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError(
        'Item name cannot be empty.',
      );
    }

    return _db.into(_db.itemDefinitions).insert(
      ItemDefinitionsCompanion.insert(
        name: cleanedName,
        defaultCategoryId:
        Value(defaultCategoryId),
        defaultUnit: Value(
          _cleanOptionalText(defaultUnit),
        ),
      ),
    );
  }

  @override
  Future<void> updateItem(
      domain.ItemDefinition item,
      ) async {
    final cleanedName = item.name.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError(
        'Item name cannot be empty.',
      );
    }

    await (_db.update(_db.itemDefinitions)
      ..where(
            (table) => table.id.equals(item.id),
      ))
        .write(
      ItemDefinitionsCompanion(
        name: Value(cleanedName),
        defaultCategoryId:
        Value(item.defaultCategoryId),
        defaultUnit: Value(
          _cleanOptionalText(item.defaultUnit),
        ),
        isActive: Value(item.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deactivateItem(int id) async {
    await (_db.update(_db.itemDefinitions)
      ..where(
            (table) => table.id.equals(id),
      ))
        .write(
      ItemDefinitionsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<bool> itemNameExists({
    required String name,
    int? excludingItemId,
  }) async {
    final normalizedName =
    name.trim().toLowerCase();

    final query = _db.select(_db.itemDefinitions)
      ..where(
            (table) =>
        table.isActive.equals(true) &
        table.name
            .lower()
            .equals(normalizedName),
      );

    if (excludingItemId != null) {
      query.where(
            (table) =>
            table.id.equals(excludingItemId).not(),
      );
    }

    final existing =
    await query.getSingleOrNull();

    return existing != null;
  }

  String? _cleanOptionalText(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  domain.ItemDefinition _mapItemDefinition(
      ItemDefinition row,
      ) {
    return domain.ItemDefinition(
      id: row.id,
      name: row.name,
      defaultCategoryId:
      row.defaultCategoryId,
      defaultUnit: row.defaultUnit,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}