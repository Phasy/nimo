import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../categories/application/category_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/presentation/transaction_detail_screen.dart';
import '../application/account_providers.dart';
import 'add_account_screen.dart';

class AccountDetailScreen
    extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({
    super.key,
    required this.accountId,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final accountAsync = ref.watch(
      accountByIdProvider(accountId),
    );

    return accountAsync.when(
      data: (account) {
        if (account == null) {
          return const Scaffold(
            backgroundColor:
            AppTheme.background,
            body:
            _AccountNotFound(),
          );
        }

        return Scaffold(
          backgroundColor:
          AppTheme.background,
          appBar: AppBar(
            title:
            const Text('Account'),
            backgroundColor:
            AppTheme.background,
            surfaceTintColor:
            Colors.transparent,
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddAccountScreen(
                            account: account,
                          ),
                    ),
                  );
                },
                tooltip: 'Edit account',
                icon: const Icon(
                  Icons.edit_outlined,
                ),
              ),
              PopupMenuButton<
                  _AccountAction>(
                tooltip:
                'Account options',
                onSelected: (action) {
                  switch (action) {
                    case _AccountAction
                        .deactivate:
                      _deactivateAccount(
                        context,
                        ref,
                        account,
                      );
                      break;

                    case _AccountAction
                        .reactivate:
                      _reactivateAccount(
                        context,
                        ref,
                        account,
                      );
                      break;
                  }
                },
                itemBuilder: (context) {
                  if (account.isActive) {
                    return [
                      const PopupMenuItem(
                        value:
                        _AccountAction
                            .deactivate,
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .archive_outlined,
                            ),
                            SizedBox(
                              width: 12,
                            ),
                            Text(
                              'Deactivate account',
                            ),
                          ],
                        ),
                      ),
                    ];
                  }

                  return [
                    const PopupMenuItem(
                      value:
                      _AccountAction
                          .reactivate,
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .unarchive_outlined,
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Reactivate account',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: _AccountDetailContent(
            account: account,
          ),
        );
      },
      loading: () {
        return const Scaffold(
          backgroundColor:
          AppTheme.background,
          body: Center(
            child:
            CircularProgressIndicator(),
          ),
        );
      },
      error: (_, __) {
        return const Scaffold(
          backgroundColor:
          AppTheme.background,
          body:
          _AccountLoadError(),
        );
      },
    );
  }

  Future<void> _deactivateAccount(
      BuildContext context,
      WidgetRef ref,
      FinanceAccount account,
      ) async {
    final hasBalance =
        account.currentBalance != 0;

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Deactivate account?',
          ),
          content: Text(
            hasBalance
                ? '${account.name} currently has a balance of ${Money.formatZmw(account.currentBalance)}.\n\nDeactivating it will remove it from active balances and new transaction selectors. Existing transactions and account history will be preserved.'
                : 'Deactivating ${account.name} will remove it from active balances and new transaction selectors.\n\nExisting transactions and account history will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(
        accountRepositoryProvider,
      );

      await repository
          .deactivateAccount(
        account.id,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${account.name} was deactivated.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not deactivate the account.',
          ),
        ),
      );
    }
  }

  Future<void> _reactivateAccount(
      BuildContext context,
      WidgetRef ref,
      FinanceAccount account,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reactivate account?',
          ),
          content: Text(
            '${account.name} will return to your active accounts and become available for new transactions again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Reactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(
        accountRepositoryProvider,
      );

      await repository
          .reactivateAccount(
        account.id,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${account.name} was reactivated.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not reactivate the account.',
          ),
        ),
      );
    }
  }
}

enum _AccountAction {
  deactivate,
  reactivate,
}

class _AccountDetailContent
    extends ConsumerWidget {
  final FinanceAccount account;

  const _AccountDetailContent({
    required this.account,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final transactionsAsync =
    ref.watch(
      transactionsForAccountProvider(
        account.id,
      ),
    );

    /*
     * Use ALL accounts here.
     *
     * Historical transfers may reference an inactive
     * account. We still need its name when displaying
     * transaction history.
     */
    final accountsAsync =
    ref.watch(
      allAccountsProvider,
    );

    final categoriesAsync =
    ref.watch(
      categoriesProvider(null),
    );

    return ListView(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        40,
      ),
      children: [
        _BalanceCard(
          account: account,
        ),
        const SizedBox(height: 28),
        const _SectionTitle(
          title: 'ACCOUNT DETAILS',
        ),
        const SizedBox(height: 10),
        _DetailsCard(
          account: account,
        ),
        const SizedBox(height: 28),
        const _SectionTitle(
          title: 'TRANSACTIONS',
        ),
        const SizedBox(height: 10),
        transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return const _EmptyTransactions();
            }

            return accountsAsync.when(
              data: (accounts) {
                return categoriesAsync.when(
                  data: (categories) {
                    return _TransactionsCard(
                      account: account,
                      transactions:
                      transactions,
                      accounts: accounts,
                      categories:
                      categories,
                    );
                  },
                  loading: () =>
                  const _TransactionsLoading(),
                  error: (_, __) =>
                  const _TransactionsError(),
                );
              },
              loading: () =>
              const _TransactionsLoading(),
              error: (_, __) =>
              const _TransactionsError(),
            );
          },
          loading: () =>
          const _TransactionsLoading(),
          error: (_, __) =>
          const _TransactionsError(),
        ),
      ],
    );
  }
}

class _BalanceCard
    extends StatelessWidget {
  final FinanceAccount account;

  const _BalanceCard({
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary
                      .withValues(
                    alpha:
                    account.isActive
                        ? 0.08
                        : 0.04,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  _iconForAccount(
                    account.type,
                  ),
                  color: account.isActive
                      ? AppTheme
                      .primaryDark
                      : AppTheme
                      .textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w700,
                        color: AppTheme
                            .textPrimary,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _labelForAccount(
                        account,
                      ),
                      style:
                      Theme.of(context)
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
              _StatusBadge(
                isActive:
                account.isActive,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'CURRENT BALANCE',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
              color: AppTheme
                  .textSecondary,
              fontWeight:
              FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Money.formatZmw(
              account.currentBalance,
            ),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
              color:
              AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (!account.isActive) ...[
            const SizedBox(height: 14),
            Text(
              'This account is inactive and is excluded from active account totals and new transaction selectors.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: AppTheme
                    .textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForAccount(
      AccountType type,
      ) {
    switch (type) {
      case AccountType.bank:
        return Icons
            .account_balance_outlined;

      case AccountType.mobileMoney:
        return Icons
            .phone_android_rounded;

      case AccountType.cash:
        return Icons
            .payments_outlined;

      case AccountType.other:
        return Icons
            .account_balance_wallet_outlined;
    }
  }

  String _labelForAccount(
      FinanceAccount account,
      ) {
    if (account.provider != null &&
        account.provider!.isNotEmpty) {
      return account.provider!;
    }

    switch (account.type) {
      case AccountType.bank:
        return 'Bank';

      case AccountType.mobileMoney:
        return 'Mobile money';

      case AccountType.cash:
        return 'Cash';

      case AccountType.other:
        return 'Other';
    }
  }
}

class _StatusBadge
    extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary
            .withValues(
          alpha: 0.08,
        )
            : AppTheme.border
            .withValues(
          alpha: 0.7,
        ),
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Text(
        isActive
            ? 'Active'
            : 'Inactive',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          color: isActive
              ? AppTheme.primaryDark
              : AppTheme
              .textSecondary,
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailsCard
    extends StatelessWidget {
  final FinanceAccount account;

  const _DetailsCard({
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Status',
            value: account.isActive
                ? 'Active'
                : 'Inactive',
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppTheme.border,
          ),
          _DetailRow(
            label: 'Account type',
            value: _accountTypeLabel(
              account.type,
            ),
          ),
          if (account.provider !=
              null &&
              account.provider!
                  .isNotEmpty) ...[
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.border,
            ),
            _DetailRow(
              label: 'Provider',
              value:
              account.provider!,
            ),
          ],
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppTheme.border,
          ),
          _DetailRow(
            label: 'Opening balance',
            value: Money.formatZmw(
              account.openingBalance,
            ),
          ),
        ],
      ),
    );
  }

  String _accountTypeLabel(
      AccountType type,
      ) {
    switch (type) {
      case AccountType.bank:
        return 'Bank';

      case AccountType.mobileMoney:
        return 'Mobile money';

      case AccountType.cash:
        return 'Cash';

      case AccountType.other:
        return 'Other';
    }
  }
}

class _TransactionsCard
    extends StatelessWidget {
  final FinanceAccount account;
  final List<FinanceTransaction>
  transactions;
  final List<FinanceAccount> accounts;
  final List<dynamic> categories;

  const _TransactionsCard({
    required this.account,
    required this.transactions,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          for (var index = 0;
          index <
              transactions.length;
          index++) ...[
            _AccountTransactionTile(
              account: account,
              transaction:
              transactions[index],
              otherAccount:
              _otherAccount(
                transactions[index],
              ),
              categoryName:
              _categoryName(
                transactions[index],
              ),
            ),
            if (index !=
                transactions.length -
                    1)
              const Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color:
                AppTheme.border,
              ),
          ],
        ],
      ),
    );
  }

  FinanceAccount? _otherAccount(
      FinanceTransaction transaction,
      ) {
    if (transaction.type !=
        TransactionType.transfer) {
      return null;
    }

    int? otherAccountId;

    if (transaction.accountId ==
        account.id) {
      otherAccountId =
          transaction
              .destinationAccountId;
    } else {
      otherAccountId =
          transaction.accountId;
    }

    if (otherAccountId == null) {
      return null;
    }

    for (final item in accounts) {
      if (item.id ==
          otherAccountId) {
        return item;
      }
    }

    return null;
  }

  String? _categoryName(
      FinanceTransaction transaction,
      ) {
    final categoryId =
        transaction.categoryId;

    if (categoryId == null) {
      return null;
    }

    for (final category
    in categories) {
      if (category.id ==
          categoryId) {
        return category.name
        as String;
      }
    }

    return null;
  }
}

class _AccountTransactionTile
    extends StatelessWidget {
  final FinanceAccount account;
  final FinanceTransaction transaction;
  final FinanceAccount? otherAccount;
  final String? categoryName;

  const _AccountTransactionTile({
    required this.account,
    required this.transaction,
    required this.otherAccount,
    required this.categoryName,
  });

  bool get _isOutgoingTransfer {
    return transaction.type ==
        TransactionType.transfer &&
        transaction.accountId ==
            account.id;
  }

  bool get _isIncomingTransfer {
    return transaction.type ==
        TransactionType.transfer &&
        transaction
            .destinationAccountId ==
            account.id;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TransactionDetailScreen(
                  transactionId:
                  transaction.id,
                ),
          ),
        );
      },
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                _icon,
                size: 20,
                color:
                AppTheme.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w600,
                      color: AppTheme
                          .textPrimary,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: AppTheme
                          .textSecondary,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    _formattedDate,
                    style:
                    Theme.of(context)
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
            const SizedBox(width: 10),
            Text(
              _formattedAmount,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                fontWeight:
                FontWeight.w700,
                color: _amountColor,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons
                  .chevron_right_rounded,
              size: 18,
              color:
              AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    if (transaction.type ==
        TransactionType.transfer) {
      final name =
          otherAccount?.name ??
              'Unknown account';

      if (_isOutgoingTransfer) {
        return 'Transfer to $name';
      }

      return 'Transfer from $name';
    }

    final payee =
    transaction.payee?.trim();

    if (payee != null &&
        payee.isNotEmpty) {
      return payee;
    }

    if (categoryName != null) {
      return categoryName!;
    }

    return transaction.type ==
        TransactionType.income
        ? 'Income'
        : 'Expense';
  }

  String get _subtitle {
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.expense:
        return categoryName ??
            'Uncategorized';

      case TransactionType.transfer:
        if (_isOutgoingTransfer &&
            transaction.fee > 0) {
          return 'Transfer • ${Money.formatZmw(transaction.fee)} fee';
        }

        return 'Transfer';
    }
  }

  String get _formattedAmount {
    switch (transaction.type) {
      case TransactionType.income:
        final net =
            transaction.amount -
                transaction.fee;

        if (net >= 0) {
          return '+${Money.formatZmw(net)}';
        }

        return Money.formatZmw(net);

      case TransactionType.expense:
        return '-${Money.formatZmw(
          transaction.amount +
              transaction.fee,
        )}';

      case TransactionType.transfer:
        if (_isIncomingTransfer) {
          return '+${Money.formatZmw(
            transaction.amount,
          )}';
        }

        return '-${Money.formatZmw(
          transaction.amount +
              transaction.fee,
        )}';
    }
  }

  Color get _amountColor {
    if (transaction.type ==
        TransactionType.income ||
        _isIncomingTransfer) {
      return Colors.green.shade700;
    }

    return AppTheme.textPrimary;
  }

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons
            .south_west_rounded;

      case TransactionType.expense:
        return Icons
            .north_east_rounded;

      case TransactionType.transfer:
        return _isIncomingTransfer
            ? Icons
            .call_received_rounded
            : Icons
            .call_made_rounded;
    }
  }

  String get _formattedDate {
    final date =
        transaction.occurredAt;

    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

class _TransactionsLoading
    extends StatelessWidget {
  const _TransactionsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: const Center(
        child:
        CircularProgressIndicator(),
      ),
    );
  }
}

class _TransactionsError
    extends StatelessWidget {
  const _TransactionsError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Text(
        'Could not load transactions for this account.',
        textAlign:
        TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(
          color:
          AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyTransactions
    extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary
                  .withValues(
                alpha: 0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons
                  .receipt_long_outlined,
              color:
              AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions yet',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight:
              FontWeight.w700,
              color:
              AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Income, expenses, and transfers involving this account will appear here.',
            textAlign:
            TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: AppTheme
                  .textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme
                    .textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign:
              TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme
                    .textPrimary,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.only(
        left: 4,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(
          color:
          AppTheme.textSecondary,
          fontWeight:
          FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _AccountNotFound
    extends StatelessWidget {
  const _AccountNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .account_balance_wallet_outlined,
              size: 42,
              color:
              AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Account not found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This account could not be found.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme
                    .textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountLoadError
    extends StatelessWidget {
  const _AccountLoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(28),
        child: Text(
          'Something went wrong while loading this account.',
          textAlign:
          TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color:
            AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}