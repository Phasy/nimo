import '../models/finance_account.dart';

abstract class AccountRepository {
  Stream<List<FinanceAccount>> watchAccounts();

  Future<FinanceAccount?> getAccount(int id);

  Future<int> createAccount({
    required String name,
    required AccountType type,
    String? provider,
    required int openingBalance,
  });

  Future<void> updateAccount(FinanceAccount account);

  Future<void> deactivateAccount(int id);

  /// Adjusts the cached/materialized current balance by [delta].
  ///
  /// Positive delta increases the balance.
  /// Negative delta decreases the balance.
  Future<void> adjustCurrentBalance(
      int accountId,
      int delta,
      );

  /// Updates the opening balance while preserving all transaction effects.
  ///
  /// Example:
  /// old opening = K1,000
  /// new opening = K1,500
  /// current balance increases by K500.
  Future<void> updateOpeningBalance({
    required int accountId,
    required int openingBalance,
  });
}