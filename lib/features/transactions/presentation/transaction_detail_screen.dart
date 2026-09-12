import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../../domain/models/transaction_line_item.dart';
import '../../accounts/application/account_providers.dart';
import '../../budget/application/budget_providers.dart';
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

  Future<List<TransactionLineItem>> _loadLineItems() {
    return ref
        .read(transactionLineItemRepositoryProvider)
        .getLineItemsForTransaction(widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(
      transactionByIdProvider(widget.transactionId),
    );

    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transaction'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _deleting ? null : _deleteTransaction,
            tooltip: 'Delete transaction',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null || transaction.isDeleted) {
            return const _MissingTransaction();
          }

          return accountsAsync.when(
            data: (accounts) {
              return categoriesAsync.when(
                data: (categories) {
                  String? accountName;
                  String? destinationName;
                  String? categoryName;

                  final categoryNames = <int, String>{};
                  for (final category in categories) {
                    categoryNames[category.id] = category.name;
                  }

                  for (final account in accounts) {
                    if (account.id == transaction.accountId) {
                      accountName = account.name;
                    }

                    if (account.id == transaction.destinationAccountId) {
                      destinationName = account.name;
                    }
                  }

                  if (transaction.categoryId != null) {
                    categoryName = categoryNames[transaction.categoryId!];
                  }

                  return FutureBuilder<List<TransactionLineItem>>(
                    future: _loadLineItems(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const _LoadingState();
                      }

                      if (snapshot.hasError) {
                        return const _LoadError();
                      }

                      final lineItems =
                          snapshot.data ?? const <TransactionLineItem>[];

                      return _TransactionDetails(
                        transaction: transaction,
                        accountName: accountName ?? 'Unknown account',
                        destinationAccountName: destinationName,
                        categoryName: categoryName,
                        categoryNames: categoryNames,
                        lineItems: lineItems,
                        deleting: _deleting,
                        onEdited: () {
                          setState(() {});
                        },
                      );
                    },
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
    );
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Could not delete transaction.';
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
  final Map<int, String> categoryNames;
  final List<TransactionLineItem> lineItems;
  final bool deleting;
  final VoidCallback onEdited;

  const _TransactionDetails({
    required this.transaction,
    required this.accountName,
    required this.destinationAccountName,
    required this.categoryName,
    required this.categoryNames,
    required this.lineItems,
    required this.deleting,
    required this.onEdited,
  });

  bool get _isItemizedExpense =>
      transaction.type == TransactionType.expense && lineItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _AmountCard(transaction: transaction),
        const SizedBox(height: 18),
        _DetailCard(
          children: [
            _DetailRow(label: 'Type', value: _typeLabel),
            _DetailRow(
              label: transaction.type == TransactionType.transfer
                  ? 'From account'
                  : 'Account',
              value: accountName,
            ),
            if (transaction.type == TransactionType.transfer)
              _DetailRow(
                label: 'To account',
                value: destinationAccountName ?? 'Unknown account',
              ),
            if (transaction.type != TransactionType.transfer)
              _DetailRow(
                label: 'Category',
                value: _isItemizedExpense
                    ? 'Itemized expense'
                    : categoryName ?? 'Uncategorized',
              ),
            _DetailRow(
              label: _isItemizedExpense ? 'Purchase' : 'Amount',
              value: Money.formatZmw(transaction.amount),
            ),
            _DetailRow(
              label: 'Fee',
              value: Money.formatZmw(transaction.fee),
            ),
            if (transaction.type == TransactionType.expense &&
                transaction.fee > 0)
              _DetailRow(
                label: 'Account impact',
                value: Money.formatZmw(
                  transaction.amount + transaction.fee,
                ),
              ),
          ],
        ),
        if (_isItemizedExpense) ...[
          const SizedBox(height: 18),
          _ItemizedExpenseCard(
            items: lineItems,
            categoryNames: categoryNames,
            transactionAmount: transaction.amount,
          ),
        ],
        const SizedBox(height: 18),
        _DetailCard(
          children: [
            if (transaction.payee != null &&
                transaction.payee!.trim().isNotEmpty)
              _DetailRow(
                label: transaction.type == TransactionType.income
                    ? 'From / payer'
                    : 'Payee',
                value: transaction.payee!,
              ),
            if (transaction.note != null &&
                transaction.note!.trim().isNotEmpty)
              _DetailRow(
                label: 'Note',
                value: transaction.note!,
              ),
            _DetailRow(
              label: 'Date',
              value: _formatDate(transaction.occurredAt),
            ),
            _DetailRow(label: 'Source', value: _sourceLabel),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: deleting
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditTransactionScreen(
                        transactionId: transaction.id,
                      ),
                    ),
                  );

                  onEdited();
                },
          icon: const Icon(Icons.edit_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _AmountCard extends StatelessWidget {
  final FinanceTransaction transaction;

  const _AmountCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _formattedAmount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
        return '+${Money.formatZmw(transaction.amount - transaction.fee)}';
      case TransactionType.expense:
        return '-${Money.formatZmw(transaction.amount + transaction.fee)}';
      case TransactionType.transfer:
        return Money.formatZmw(transaction.amount);
    }
  }

  Color get _amountColor {
    if (transaction.type == TransactionType.income) {
      return Colors.green.shade700;
    }

    return AppTheme.textPrimary;
  }
}

class _ItemizedExpenseCard extends StatelessWidget {
  final List<TransactionLineItem> items;
  final Map<int, String> categoryNames;
  final int transactionAmount;

  const _ItemizedExpenseCard({
    required this.items,
    required this.categoryNames,
    required this.transactionAmount,
  });

  @override
  Widget build(BuildContext context) {
    final itemTotal = items.fold<int>(
      0,
      (total, item) => total + item.amount,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${items.length} ${items.length == 1 ? 'item' : 'items'} in this expense',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(items.length, (index) {
            final item = items[index];

            return Column(
              children: [
                _TransactionLineItemRow(
                  item: item,
                  categoryName:
                      categoryNames[item.categoryId] ?? 'Unknown category',
                ),
                if (index != items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                  ),
              ],
            );
          }),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Items total',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      Money.formatZmw(itemTotal),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                if (itemTotal != transactionAmount) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 17,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Items total does not match the transaction purchase amount of '
                          '${Money.formatZmw(transactionAmount)}.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange.shade800,
                                    height: 1.35,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionLineItemRow extends StatelessWidget {
  final TransactionLineItem item;
  final String categoryName;

  const _TransactionLineItemRow({
    required this.item,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameSnapshot,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                ),
                if (item.monthlyPlannedItemId != null) ...[
                  const SizedBox(height: 7),
                  const _PlanLinkBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            Money.formatZmw(item.amount),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final quantityText = _quantityText;

    if (quantityText == null) {
      return categoryName;
    }

    return '$categoryName • $quantityText';
  }

  String? get _quantityText {
    final quantity = item.quantity;

    if (quantity == null) {
      return null;
    }

    final formattedQuantity = Quantity.format(quantity);
    final unit = item.unitSnapshot?.trim();

    if (unit == null || unit.isEmpty) {
      return formattedQuantity;
    }

    return '$formattedQuantity $unit';
  }
}

class _PlanLinkBadge extends StatelessWidget {
  const _PlanLinkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 14,
            color: AppTheme.primaryDark,
          ),
          const SizedBox(width: 5),
          Text(
            'Linked to budget plan',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}
