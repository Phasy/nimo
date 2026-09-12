import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/finance_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class DriftTransactionRepository
    implements TransactionRepository {
  final AppDatabase database;

  DriftTransactionRepository(this.database);

  @override
  Stream<List<FinanceTransaction>> watchTransactions() {
    final query = database.select(database.transactions)
      ..where(
            (transaction) =>
            transaction.isDeleted.equals(false),
      )
      ..orderBy([
            (transaction) => OrderingTerm.desc(
          transaction.occurredAt,
        ),
            (transaction) => OrderingTerm.desc(
          transaction.id,
        ),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapTransaction).toList(),
    );
  }

  @override
  Stream<List<FinanceTransaction>>
  watchTransactionsForAccount(
      int accountId,
      ) {
    final query = database.select(database.transactions)
      ..where(
            (transaction) =>
        transaction.isDeleted.equals(false) &
        (
            transaction.accountId.equals(accountId) |
            transaction.destinationAccountId
                .equals(accountId)
        ),
      )
      ..orderBy([
            (transaction) => OrderingTerm.desc(
          transaction.occurredAt,
        ),
            (transaction) => OrderingTerm.desc(
          transaction.id,
        ),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapTransaction).toList(),
    );
  }

  @override
  Future<FinanceTransaction?> getTransaction(
      int id,
      ) async {
    final query = database.select(database.transactions)
      ..where(
            (transaction) => transaction.id.equals(id),
      );

    final row = await query.getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapTransaction(row);
  }

  @override
  Future<List<FinanceTransaction>>
  getTransactionsBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    if (!endExclusive.isAfter(startInclusive)) {
      throw ArgumentError(
        'Transaction date range must have an end after its start.',
      );
    }

    final query = database.select(database.transactions)
      ..where(
            (transaction) =>
        transaction.isDeleted.equals(false) &
        transaction.occurredAt
            .isBiggerOrEqualValue(startInclusive) &
        transaction.occurredAt
            .isSmallerThanValue(endExclusive),
      )
      ..orderBy([
            (transaction) => OrderingTerm.asc(
          transaction.occurredAt,
        ),
            (transaction) => OrderingTerm.asc(
          transaction.id,
        ),
      ]);

    final rows = await query.get();

    return rows.map(_mapTransaction).toList();
  }

  @override
  Future<List<FinanceTransaction>>
  getTransactionsFrom({
    required DateTime startInclusive,
  }) async {
    final query = database.select(database.transactions)
      ..where(
            (transaction) =>
        transaction.isDeleted.equals(false) &
        transaction.occurredAt
            .isBiggerOrEqualValue(startInclusive),
      )
      ..orderBy([
            (transaction) => OrderingTerm.asc(
          transaction.occurredAt,
        ),
            (transaction) => OrderingTerm.asc(
          transaction.id,
        ),
      ]);

    final rows = await query.get();

    return rows.map(_mapTransaction).toList();
  }

  @override
  Future<int> createTransaction({
    required TransactionType type,
    required int accountId,
    int? destinationAccountId,
    int? categoryId,
    required int amount,
    int fee = 0,
    String? payee,
    String? note,
    required DateTime occurredAt,
    TransactionSource source =
        TransactionSource.manual,
    String? externalTransactionId,
  }) {
    return database.into(database.transactions).insert(
      TransactionsCompanion.insert(
        type: type.value,
        accountId: accountId,
        destinationAccountId:
        Value(destinationAccountId),
        categoryId: Value(categoryId),
        amount: amount,
        fee: Value(fee),
        payee: Value(_cleanOptionalText(payee)),
        note: Value(_cleanOptionalText(note)),
        occurredAt: occurredAt,
        source: Value(source.value),
        externalTransactionId: Value(
          _cleanOptionalText(
            externalTransactionId,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> updateTransaction(
      FinanceTransaction transaction,
      ) async {
    await (database.update(database.transactions)
      ..where(
            (row) => row.id.equals(transaction.id),
      ))
        .write(
      TransactionsCompanion(
        type: Value(transaction.type.value),
        accountId: Value(transaction.accountId),
        destinationAccountId: Value(
          transaction.destinationAccountId,
        ),
        categoryId: Value(transaction.categoryId),
        amount: Value(transaction.amount),
        fee: Value(transaction.fee),
        payee: Value(
          _cleanOptionalText(transaction.payee),
        ),
        note: Value(
          _cleanOptionalText(transaction.note),
        ),
        occurredAt: Value(transaction.occurredAt),
        source: Value(transaction.source.value),
        externalTransactionId: Value(
          _cleanOptionalText(
            transaction.externalTransactionId,
          ),
        ),
        isDeleted: Value(transaction.isDeleted),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markDeleted(int id) async {
    await (database.update(database.transactions)
      ..where(
            (transaction) =>
            transaction.id.equals(id),
      ))
        .write(
      TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  FinanceTransaction _mapTransaction(
      Transaction row,
      ) {
    return FinanceTransaction(
      id: row.id,
      type: TransactionTypeX.fromValue(row.type),
      accountId: row.accountId,
      destinationAccountId:
      row.destinationAccountId,
      categoryId: row.categoryId,
      amount: row.amount,
      fee: row.fee,
      payee: row.payee,
      note: row.note,
      occurredAt: row.occurredAt,
      source: TransactionSourceX.fromValue(
        row.source,
      ),
      externalTransactionId:
      row.externalTransactionId,
      isDeleted: row.isDeleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String? _cleanOptionalText(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}