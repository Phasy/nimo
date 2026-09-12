import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';
import 'edit_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _deleting = false;

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This will reverse the transaction’s effect on your account balance. '
                'The transaction will remain preserved in Nomi’s history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await ref
          .read(transactionServiceProvider)
          .deleteTransaction(widget.transactionId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(error),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(
      transactionByIdProvider(widget.transactionId),
    );

    final accountsAsync = ref.watch(accountsProvider);

    final categoriesAsync = ref.watch(
      categoriesProvider(null),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transaction'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _deleting
                ? null
                : _deleteTransaction,
            tooltip: 'Delete transaction',
            icon: const Icon(
              Icons.delete_outline_rounded,
            ),
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null ||
              transaction.isDeleted) {
            return const _MissingTransaction();
          }

          return accountsAsync.when(
            data: (accounts) {
              return categoriesAsync.when(
                data: (categories) {
                  String? accountName;
                  String? destinationName;
                  String? categoryName;

                  for (final account in accounts) {
                    if (account.id ==
                        transaction.accountId) {
                      accountName = account.name;
                    }

                    if (account.id ==
                        transaction
                            .destinationAccountId) {
                      destinationName =
                          account.name;
                    }
                  }

                  if (transaction.categoryId != null) {
                    for (final category
                    in categories) {
                      if (category.id ==
                          transaction.categoryId) {
                        categoryName =
                            category.name;
                        break;
                      }
                    }
                  }

                  return _TransactionDetails(
                    transaction: transaction,
                    accountName:
                    accountName ?? 'Unknown account',
                    destinationAccountName:
                    destinationName,
                    categoryName: categoryName,
                    deleting: _deleting,
                  );
                },
                loading: () =>
                const _LoadingState(),
                error: (_, __) =>
                const _LoadError(),
              );
            },
            loading: () => const _LoadingState(),
            error: (_, __) => const _LoadError(),
          );
        },
        loading: () => const _LoadingState(),
        error: (_, __) => const _LoadError(),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Could not delete transaction.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Could not delete transaction.';
  }
}

class _TransactionDetails extends StatelessWidget {
  final FinanceTransaction transaction;
  final String accountName;
  final String? destinationAccountName;
  final String? categoryName;
  final bool deleting;

  const _TransactionDetails({
    required this.transaction,
    required this.accountName,
    required this.destinationAccountName,
    required this.categoryName,
    required this.deleting,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        40,
      ),
      children: [
        _AmountCard(
          transaction: transaction,
        ),

        const SizedBox(height: 18),

        _DetailCard(
          children: [
            _DetailRow(
              label: 'Type',
              value: _typeLabel,
            ),

            _DetailRow(
              label: transaction.type ==
                  TransactionType.transfer
                  ? 'From account'
                  : 'Account',
              value: accountName,
            ),

            if (transaction.type ==
                TransactionType.transfer)
              _DetailRow(
                label: 'To account',
                value: destinationAccountName ??
                    'Unknown account',
              ),

            if (transaction.type !=
                TransactionType.transfer)
              _DetailRow(
                label: 'Category',
                value:
                categoryName ?? 'Uncategorized',
              ),

            _DetailRow(
              label: 'Amount',
              value: Money.formatZmw(
                transaction.amount,
              ),
            ),

            _DetailRow(
              label: 'Fee',
              value: Money.formatZmw(
                transaction.fee,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _DetailCard(
          children: [
            if (transaction.payee != null &&
                transaction.payee!
                    .trim()
                    .isNotEmpty)
              _DetailRow(
                label: transaction.type ==
                    TransactionType.income
                    ? 'From / payer'
                    : 'Payee',
                value: transaction.payee!,
              ),

            if (transaction.note != null &&
                transaction.note!
                    .trim()
                    .isNotEmpty)
              _DetailRow(
                label: 'Note',
                value: transaction.note!,
              ),

            _DetailRow(
              label: 'Date',
              value: _formatDate(
                transaction.occurredAt,
              ),
            ),

            _DetailRow(
              label: 'Source',
              value: _sourceLabel,
            ),
          ],
        ),

        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: deleting
              ? null
              : () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    EditTransactionScreen(
                      transactionId:
                      transaction.id,
                    ),
              ),
            );
          },
          icon: const Icon(
            Icons.edit_outlined,
          ),
          label: const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Text('Edit transaction'),
          ),
        ),
      ],
    );
  }

  String get _typeLabel {
    switch (transaction.type) {
      case TransactionType.income:
        return 'Income';

      case TransactionType.expense:
        return 'Expense';

      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  String get _sourceLabel {
    switch (transaction.source) {
      case TransactionSource.manual:
        return 'Manual';

      case TransactionSource.sms:
        return 'SMS';
    }
  }

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

class _AmountCard extends StatelessWidget {
  final FinanceTransaction transaction;

  const _AmountCard({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formattedAmount,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: _amountColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (transaction.type) {
      case TransactionType.income:
        return 'NET RECEIVED';

      case TransactionType.expense:
        return 'TOTAL SPENT';

      case TransactionType.transfer:
        return 'TRANSFER AMOUNT';
    }
  }

  String get _formattedAmount {
    switch (transaction.type) {
      case TransactionType.income:
        return '+${Money.formatZmw(
          transaction.amount -
              transaction.fee,
        )}';

      case TransactionType.expense:
        return '-${Money.formatZmw(
          transaction.amount +
              transaction.fee,
        )}';

      case TransactionType.transfer:
        return Money.formatZmw(
          transaction.amount,
        );
    }
  }

  Color get _amountColor {
    if (transaction.type ==
        TransactionType.income) {
      return Colors.green.shade700;
    }

    return AppTheme.textPrimary;
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
          'Something went wrong while loading this transaction.',
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

class _MissingTransaction extends StatelessWidget {
  const _MissingTransaction();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This transaction is no longer available.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}