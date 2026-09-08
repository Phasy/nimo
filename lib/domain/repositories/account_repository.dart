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
}