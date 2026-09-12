import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/account_repository_impl.dart';
import '../../../data/repositories/budget_repository_impl.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../../services/account_budget_service.dart';

final databaseProvider =
Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});

final accountRepositoryProvider =
Provider<AccountRepository>((ref) {
  final database =
  ref.watch(databaseProvider);

  return DriftAccountRepository(
    database,
  );
});

/// Active accounts only.
///
/// Used for normal working screens, transaction
/// selectors, and dashboard totals.
final accountsProvider =
StreamProvider<List<FinanceAccount>>(
      (ref) {
    final repository = ref.watch(
      accountRepositoryProvider,
    );

    return repository.watchAccounts();
  },
);

/// Active + inactive accounts.
///
/// Used anywhere historical account identity must
/// remain available after deactivation.
final allAccountsProvider =
StreamProvider<List<FinanceAccount>>(
      (ref) {
    final repository = ref.watch(
      accountRepositoryProvider,
    );

    return repository.watchAllAccounts();
  },
);

/// Convenience provider containing inactive accounts
/// only.
final inactiveAccountsProvider =
Provider<AsyncValue<List<FinanceAccount>>>(
      (ref) {
    final accountsAsync =
    ref.watch(allAccountsProvider);

    return accountsAsync.whenData(
          (accounts) => accounts
          .where(
            (account) =>
        !account.isActive,
      )
          .toList(),
    );
  },
);

/// Total money intentionally uses ACTIVE accounts only.
final totalAccountBalanceProvider =
Provider<AsyncValue<int>>((ref) {
  final accountsAsync =
  ref.watch(accountsProvider);

  return accountsAsync.whenData(
        (accounts) => accounts.fold<int>(
      0,
          (total, account) =>
      total +
          account.currentBalance,
    ),
  );
});

/// Account lookup uses ALL accounts so an account does
/// not become "not found" immediately after it is
/// deactivated.
final accountByIdProvider =
Provider.family<
    AsyncValue<FinanceAccount?>,
    int>(
      (ref, accountId) {
    final accountsAsync =
    ref.watch(allAccountsProvider);

    return accountsAsync.whenData(
          (accounts) {
        for (final account in accounts) {
          if (account.id ==
              accountId) {
            return account;
          }
        }

        return null;
      },
    );
  },
);

final accountBudgetServiceProvider = Provider<AccountBudgetService>((ref) {
  final database = ref.watch(databaseProvider);

  return AccountBudgetService(
    transactionRunner: AppDatabaseTransactionRunner(database),
    accountRepository: ref.watch(accountRepositoryProvider),
    budgetRepository: DriftBudgetRepository(database),
  );
});
