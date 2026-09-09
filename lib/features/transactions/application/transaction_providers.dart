import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/transaction_repository_impl.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../services/transaction_service.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';

final transactionRepositoryProvider =
Provider<TransactionRepository>((ref) {
  final database = ref.watch(databaseProvider);

  return DriftTransactionRepository(database);
});

final transactionServiceProvider =
Provider<TransactionService>((ref) {
  final database = ref.watch(databaseProvider);
  final transactionRepository =
  ref.watch(transactionRepositoryProvider);
  final accountRepository =
  ref.watch(accountRepositoryProvider);
  final categoryRepository =
  ref.watch(categoryRepositoryProvider);

  return TransactionService(
    database: database,
    transactionRepository: transactionRepository,
    accountRepository: accountRepository,
    categoryRepository: categoryRepository,
  );
});

final transactionsProvider =
StreamProvider<List<FinanceTransaction>>((ref) {
  final repository =
  ref.watch(transactionRepositoryProvider);

  return repository.watchTransactions();
});

final transactionsForAccountProvider = StreamProvider.family<
    List<FinanceTransaction>,
    int>((ref, accountId) {
  final repository =
  ref.watch(transactionRepositoryProvider);

  return repository.watchTransactionsForAccount(
    accountId,
  );
});

final transactionByIdProvider = FutureProvider.family<
    FinanceTransaction?,
    int>((ref, transactionId) {
  final repository =
  ref.watch(transactionRepositoryProvider);

  return repository.getTransaction(transactionId);
});