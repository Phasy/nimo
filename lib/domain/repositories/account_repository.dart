import '../models/finance_account.dart';

abstract class AccountRepository {
  /// Watches active accounts only.
  ///
  /// This is the normal working set used by:
  /// - transaction selectors
  /// - dashboard totals
  /// - normal account lists
  Stream<List<FinanceAccount>> watchAccounts();

  /// Watches both active and inactive accounts.
  ///
  /// This is used where historical account identity must
  /// remain available after an account is deactivated.
  Stream<List<FinanceAccount>> watchAllAccounts();

  Future<FinanceAccount?> getAccount(int id);

  Future<int> createAccount({
    required String name,
    required AccountType type,
    String? provider,
    required int openingBalance,
  });

  Future<void> updateAccount(
      FinanceAccount account,
      );

  /// Soft-deactivates an account.
  ///
  /// No balances or historical transactions are changed.
  Future<void> deactivateAccount(int id);

  /// Reactivates a previously deactivated account.
  Future<void> reactivateAccount(int id);

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