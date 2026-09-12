import '../core/database/app_database.dart';
import '../domain/models/finance_account.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/budget_repository.dart';

class AccountBudgetService {
  const AccountBudgetService({
    required this.transactionRunner,
    required this.accountRepository,
    required this.budgetRepository,
  });

  final DatabaseTransactionRunner transactionRunner;
  final AccountRepository accountRepository;
  final BudgetRepository budgetRepository;

  Future<void> updateAccount(FinanceAccount account) async {
    await transactionRunner.run(() async {
      final existing = await accountRepository.getAccount(account.id);

      if (existing == null) {
        throw StateError('Account ${account.id} does not exist.');
      }

      final openingBalanceDifference =
          account.openingBalance - existing.openingBalance;

      await accountRepository.updateAccount(account);

      if (openingBalanceDifference == 0) {
        return;
      }

      final budgetSettings = await budgetRepository.getBudgetSettings();

      if (budgetSettings == null) {
        return;
      }

      await budgetRepository.updateInitialAssignableAmount(
        delta: openingBalanceDifference,
      );
    });
  }
}

abstract class DatabaseTransactionRunner {
  Future<void> run(Future<void> Function() action);
}

class AppDatabaseTransactionRunner implements DatabaseTransactionRunner {
  const AppDatabaseTransactionRunner(this.database);

  final AppDatabase database;

  @override
  Future<void> run(Future<void> Function() action) {
    return database.transaction(action);
  }
}
