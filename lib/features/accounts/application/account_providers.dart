import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/account_repository_impl.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/repositories/account_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final database = ref.watch(databaseProvider);

  return DriftAccountRepository(database);
});

final accountsProvider = StreamProvider<List<FinanceAccount>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);

  return repository.watchAccounts();
});

final totalAccountBalanceProvider = Provider<AsyncValue<int>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);

  return accountsAsync.whenData(
        (accounts) => accounts.fold<int>(
      0,
          (total, account) => total + account.currentBalance,
    ),
  );
});

final accountByIdProvider =
Provider.family<AsyncValue<FinanceAccount?>, int>((ref, accountId) {
  final accountsAsync = ref.watch(accountsProvider);

  return accountsAsync.whenData((accounts) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }

    return null;
  });
});