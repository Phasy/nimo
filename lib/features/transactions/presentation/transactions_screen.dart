import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_category.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(
      transactionsProvider,
    );

    final accountsAsync = ref.watch(
      accountsProvider,
    );

    final categoriesAsync = ref.watch(
      categoriesProvider(null),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const _EmptyTransactions();
          }

          return accountsAsync.when(
            data: (accounts) {
              return categoriesAsync.when(
                data: (categories) {
                  return _TransactionsList(
                    transactions: transactions,
                    accounts: accounts,
                    categories: categories,
                  );
                },
                loading: () => const _LoadingState(),
                error: (_, __) => const _LoadError(),
              );
            },
            loading: () => const _LoadingState(),
            error: (_, __) => const _LoadError(),
          );
        },
        loading: () => const _LoadingState(),
        error: (_, __) => const _LoadError(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
              const AddTransactionScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;

  const _TransactionsList({
    required this.transactions,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        100,
      ),
      itemCount: transactions.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final transaction = transactions[index];

        return _TransactionTile(
          transaction: transaction,
          sourceAccount: _findAccount(
            transaction.accountId,
          ),
          destinationAccount: transaction
              .destinationAccountId ==
              null
              ? null
              : _findAccount(
            transaction.destinationAccountId!,
          ),
          category: transaction.categoryId == null
              ? null
              : _findCategory(
            transaction.categoryId!,
          ),
        );
      },
    );
  }

  FinanceAccount? _findAccount(int id) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  FinanceCategory? _findCategory(int id) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }
}

class _TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final FinanceAccount? sourceAccount;
  final FinanceAccount? destinationAccount;
  final FinanceCategory? category;

  const _TransactionTile({
    required this.transaction,
    required this.sourceAccount,
    required this.destinationAccount,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(
                transactionId: transaction.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w600,
                        color:
                        AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: AppTheme
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _formattedDate,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: AppTheme
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Text(
                _formattedAmount,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _amountColor,
                ),
              ),

              const SizedBox(width: 6),

              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    switch (transaction.type) {
      case TransactionType.income:
        final payee = transaction.payee?.trim();

        if (payee != null && payee.isNotEmpty) {
          return payee;
        }

        return category?.name ?? 'Income';

      case TransactionType.expense:
        final payee = transaction.payee?.trim();

        if (payee != null && payee.isNotEmpty) {
          return payee;
        }

        return category?.name ?? 'Expense';

      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  String get _subtitle {
    final accountName =
        sourceAccount?.name ?? 'Unknown account';

    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.expense:
        final categoryName =
            category?.name ?? 'Uncategorized';

        return '$categoryName • $accountName';

      case TransactionType.transfer:
        final destinationName =
            destinationAccount?.name ??
                'Unknown account';

        return '$accountName → $destinationName';
    }
  }

  String get _formattedDate {
    final date = transaction.occurredAt;

    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String get _formattedAmount {
    switch (transaction.type) {
      case TransactionType.income:
        return '+${Money.formatZmw(
          transaction.amount - transaction.fee,
        )}';

      case TransactionType.expense:
        return '-${Money.formatZmw(
          transaction.amount + transaction.fee,
        )}';

      case TransactionType.transfer:
        return Money.formatZmw(
          transaction.amount,
        );
    }
  }

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.south_west_rounded;

      case TransactionType.expense:
        return Icons.north_east_rounded;

      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  Color get _amountColor {
    switch (transaction.type) {
      case TransactionType.income:
        return Colors.green.shade700;

      case TransactionType.expense:
      case TransactionType.transfer:
        return AppTheme.textPrimary;
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Something went wrong while loading your transactions.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No transactions yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first income, expense, or transfer.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}