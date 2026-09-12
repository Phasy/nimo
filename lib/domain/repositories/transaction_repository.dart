import '../models/finance_transaction.dart';

abstract class TransactionRepository {
  /// Watches all non-deleted transactions, newest financial event first.
  Stream<List<FinanceTransaction>> watchTransactions();

  /// Watches transactions involving a particular account.
  ///
  /// This includes:
  /// - income received by the account
  /// - expenses paid from the account
  /// - transfers sent from the account
  /// - transfers received by the account
  Stream<List<FinanceTransaction>> watchTransactionsForAccount(
      int accountId,
      );

  Future<FinanceTransaction?> getTransaction(int id);

  /// Returns non-deleted transactions whose financial event falls within:
  ///
  /// occurredAt >= [startInclusive]
  /// occurredAt <  [endExclusive]
  ///
  /// Using an exclusive upper bound avoids end-of-month/time precision
  /// problems.
  Future<List<FinanceTransaction>> getTransactionsBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Returns non-deleted transactions from [startInclusive] onward.
  ///
  /// Primarily useful for cumulative budget calculations.
  Future<List<FinanceTransaction>> getTransactionsFrom({
    required DateTime startInclusive,
  });

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
    TransactionSource source = TransactionSource.manual,
    String? externalTransactionId,
  });

  Future<void> updateTransaction(
      FinanceTransaction transaction,
      );

  Future<void> markDeleted(int id);
}