import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/transaction_line_item.dart'
as domain;
import '../../domain/models/item_price_history.dart'
as domain;
import '../../domain/repositories/transaction_line_item_repository.dart';

class DriftTransactionLineItemRepository
    implements TransactionLineItemRepository {
  DriftTransactionLineItemRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.TransactionLineItem>>
  watchLineItemsForTransaction(
      int transactionId,
      ) {
    final query =
    _db.select(_db.transactionLineItems)
      ..where(
            (table) => table.transactionId.equals(
          transactionId,
        ),
      )
      ..orderBy([
            (table) => OrderingTerm.asc(table.id),
      ]);

    return query.watch().map(
          (rows) =>
          rows.map(_mapLineItem).toList(),
    );
  }

  @override
  Future<List<domain.TransactionLineItem>>
  getLineItemsForTransaction(
      int transactionId,
      ) async {
    final query =
    _db.select(_db.transactionLineItems)
      ..where(
            (table) => table.transactionId.equals(
          transactionId,
        ),
      )
      ..orderBy([
            (table) => OrderingTerm.asc(table.id),
      ]);

    final rows = await query.get();

    return rows.map(_mapLineItem).toList();
  }

  @override
  Future<domain.TransactionLineItem?> getLineItem(
      int id,
      ) async {
    final query =
    _db.select(_db.transactionLineItems)
      ..where(
            (table) => table.id.equals(id),
      );

    final row = await query.getSingleOrNull();

    return row == null ? null : _mapLineItem(row);
  }

  @override
  Future<int> createLineItem({
    required int transactionId,
    required int categoryId,
    int? itemDefinitionId,
    int? monthlyPlannedItemId,
    required String nameSnapshot,
    int? quantity,
    String? unitSnapshot,
    required int amount,
  }) {
    final cleanedName = nameSnapshot.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError(
        'Line item name cannot be empty.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Line item amount must be greater than zero.',
      );
    }

    if (quantity != null && quantity <= 0) {
      throw ArgumentError(
        'Line item quantity must be greater than zero.',
      );
    }

    return _db.into(_db.transactionLineItems).insert(
      TransactionLineItemsCompanion.insert(
        transactionId: transactionId,
        categoryId: categoryId,
        itemDefinitionId:
        Value(itemDefinitionId),
        monthlyPlannedItemId:
        Value(monthlyPlannedItemId),
        nameSnapshot: cleanedName,
        quantity: Value(quantity),
        unitSnapshot: Value(
          _cleanOptionalText(unitSnapshot),
        ),
        amount: amount,
      ),
    );
  }

  @override
  Future<void> updateLineItem(
      domain.TransactionLineItem item,
      ) async {
    final cleanedName =
    item.nameSnapshot.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError(
        'Line item name cannot be empty.',
      );
    }

    if (item.amount <= 0) {
      throw ArgumentError(
        'Line item amount must be greater than zero.',
      );
    }

    if (item.quantity != null &&
        item.quantity! <= 0) {
      throw ArgumentError(
        'Line item quantity must be greater than zero.',
      );
    }

    await (_db.update(_db.transactionLineItems)
      ..where(
            (table) => table.id.equals(item.id),
      ))
        .write(
      TransactionLineItemsCompanion(
        transactionId:
        Value(item.transactionId),
        categoryId: Value(item.categoryId),
        itemDefinitionId:
        Value(item.itemDefinitionId),
        monthlyPlannedItemId:
        Value(item.monthlyPlannedItemId),
        nameSnapshot: Value(cleanedName),
        quantity: Value(item.quantity),
        unitSnapshot: Value(
          _cleanOptionalText(item.unitSnapshot),
        ),
        amount: Value(item.amount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteLineItem(int id) async {
    await (_db.delete(_db.transactionLineItems)
      ..where(
            (table) => table.id.equals(id),
      ))
        .go();
  }

  @override
  Future<void> deleteLineItemsForTransaction(
      int transactionId,
      ) async {
    await (_db.delete(_db.transactionLineItems)
      ..where(
            (table) => table.transactionId.equals(
          transactionId,
        ),
      ))
        .go();
  }

  @override
  Future<List<domain.TransactionLineItem>>
  getLineItemsForPlannedItem(
      int monthlyPlannedItemId,
      ) async {
    final query = _db.select(_db.transactionLineItems).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(
          _db.transactionLineItems.transactionId,
        ),
      ),
    ])
      ..where(
        _db.transactionLineItems.monthlyPlannedItemId
                .equals(monthlyPlannedItemId) &
            _db.transactions.isDeleted.equals(false),
      )
      ..orderBy([
        OrderingTerm.asc(_db.transactionLineItems.id),
      ]);

    final rows = await query.get();

    return rows
        .map((row) => _mapLineItem(row.readTable(_db.transactionLineItems)))
        .toList();
  }

  @override
  Future<List<domain.TransactionLineItem>>
  getLineItemsForItemDefinition(
      int itemDefinitionId,
      ) async {
    //
    // Join Transactions so deleted ledger records do not
    // contribute to price history.
    //
    final query = _db.select(_db.transactionLineItems)
        .join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(
          _db.transactionLineItems.transactionId,
        ),
      ),
    ])
      ..where(
        _db.transactionLineItems.itemDefinitionId
            .equals(itemDefinitionId) &
        _db.transactions.isDeleted.equals(false),
      )
      ..orderBy([
        OrderingTerm.asc(
          _db.transactions.occurredAt,
        ),
        OrderingTerm.asc(
          _db.transactionLineItems.id,
        ),
      ]);

    final rows = await query.get();

    return rows
        .map(
          (row) => _mapLineItem(
        row.readTable(
          _db.transactionLineItems,
        ),
      ),
    )
        .toList();
  }

  @override
  Future<List<domain.ItemPurchaseHistoryEntry>> getActivePurchaseHistory({
    int? itemDefinitionId,
    int? monthlyPlannedItemId,
  }) async {
    if ((itemDefinitionId == null) == (monthlyPlannedItemId == null)) {
      throw ArgumentError(
        'Provide exactly one stable item definition or monthly planned item.',
      );
    }

    final query = _db.select(_db.transactionLineItems).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(
          _db.transactionLineItems.transactionId,
        ),
      ),
    ])
      ..where(_db.transactions.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm.desc(_db.transactions.occurredAt),
        OrderingTerm.desc(_db.transactionLineItems.id),
      ]);

    if (itemDefinitionId != null) {
      query.where(
        _db.transactionLineItems.itemDefinitionId.equals(itemDefinitionId),
      );
    } else {
      query.where(
        _db.transactionLineItems.monthlyPlannedItemId.equals(
          monthlyPlannedItemId!,
        ),
      );
    }

    final rows = await query.get();

    return rows.map((row) {
      final line = row.readTable(_db.transactionLineItems);
      final transaction = row.readTable(_db.transactions);

      return domain.ItemPurchaseHistoryEntry(
        transactionLineItemId: line.id,
        transactionId: transaction.id,
        occurredAt: transaction.occurredAt,
        payee: transaction.payee,
        quantity: line.quantity,
        unit: line.unitSnapshot,
        amount: line.amount,
      );
    }).toList();
  }

  @override
  Future<List<domain.TransactionLineItem>>
  getLineItemsForTransactions(
      List<int> transactionIds,
      ) async {
    if (transactionIds.isEmpty) {
      return [];
    }

    final query =
    _db.select(_db.transactionLineItems)
      ..where(
            (table) =>
            table.transactionId.isIn(
              transactionIds,
            ),
      )
      ..orderBy([
            (table) =>
            OrderingTerm.asc(table.transactionId),
            (table) => OrderingTerm.asc(table.id),
      ]);

    final rows = await query.get();

    return rows.map(_mapLineItem).toList();
  }

  String? _cleanOptionalText(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  domain.TransactionLineItem _mapLineItem(
      TransactionLineItem row,
      ) {
    return domain.TransactionLineItem(
      id: row.id,
      transactionId: row.transactionId,
      categoryId: row.categoryId,
      itemDefinitionId: row.itemDefinitionId,
      monthlyPlannedItemId:
      row.monthlyPlannedItemId,
      nameSnapshot: row.nameSnapshot,
      quantity: row.quantity,
      unitSnapshot: row.unitSnapshot,
      amount: row.amount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
