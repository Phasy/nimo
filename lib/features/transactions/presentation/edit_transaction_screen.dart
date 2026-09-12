import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../../domain/models/monthly_planned_item.dart';
import '../../../domain/models/transaction_line_item.dart';
import '../../../services/transaction_service.dart';
import '../../accounts/application/account_providers.dart';
import '../../budget/application/budget_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final int transactionId;

  const EditTransactionScreen({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState
    extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();

  late final Future<List<TransactionLineItem>> _lineItemsFuture;

  FinanceTransaction? _transaction;

  int? _accountId;
  int? _destinationAccountId;
  int? _categoryGroupId;
  int? _categoryId;

  DateTime? _occurredAt;

  bool _initialized = false;
  bool _saving = false;
  bool _itemized = false;

  final List<_ExpenseLineDraft> _expenseLines = [];

  @override
  void initState() {
    super.initState();

    _lineItemsFuture = ref
        .read(transactionLineItemRepositoryProvider)
        .getLineItemsForTransaction(widget.transactionId);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _payeeController.dispose();
    _noteController.dispose();

    for (final line in _expenseLines) {
      line.dispose();
    }

    super.dispose();
  }

  void _initialize(
    FinanceTransaction transaction,
    List<dynamic> categories,
    List<TransactionLineItem> lineItems,
  ) {
    if (_initialized) {
      return;
    }

    _transaction = transaction;

    _accountId = transaction.accountId;
    _destinationAccountId = transaction.destinationAccountId;
    _categoryId = transaction.categoryId;
    _occurredAt = transaction.occurredAt;

    _amountController.text =
        Money.formatMinorUnits(transaction.amount);

    _feeController.text = transaction.fee == 0
        ? ''
        : Money.formatMinorUnits(transaction.fee);

    _payeeController.text = transaction.payee ?? '';
    _noteController.text = transaction.note ?? '';

    if (transaction.categoryId != null) {
      for (final category in categories) {
        if (category.id == transaction.categoryId) {
          _categoryGroupId = category.groupId;
          break;
        }
      }
    }

    if (transaction.type == TransactionType.expense &&
        lineItems.isNotEmpty) {
      _itemized = true;
      _categoryGroupId = null;
      _categoryId = null;

      for (final item in lineItems) {
        int? groupId;

        for (final category in categories) {
          if (category.id == item.categoryId) {
            groupId = category.groupId;
            break;
          }
        }

        _expenseLines.add(
          _ExpenseLineDraft.fromExisting(
            item,
            categoryGroupId: groupId,
          ),
        );
      }
    }

    _initialized = true;
  }

  void _setItemized(bool value) {
    setState(() {
      _itemized = value;

      if (_itemized) {
        _categoryGroupId = null;
        _categoryId = null;

        if (_expenseLines.isEmpty) {
          _expenseLines.add(_ExpenseLineDraft());
        }
      } else {
        for (final line in _expenseLines) {
          line.dispose();
        }

        _expenseLines.clear();
      }
    });
  }

  void _addExpenseLine() {
    setState(() {
      _expenseLines.add(_ExpenseLineDraft());
    });
  }

  void _removeExpenseLine(int index) {
    if (index < 0 || index >= _expenseLines.length) {
      return;
    }

    setState(() {
      final removed = _expenseLines.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    final transaction = _transaction;

    if (transaction == null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = Money.tryParseToMinorUnits(
      _amountController.text,
    );

    final feeText = _feeController.text.trim();

    final fee = feeText.isEmpty
        ? 0
        : Money.tryParseToMinorUnits(feeText);

    if (amount == null || amount <= 0) {
      return;
    }

    if (fee == null || fee < 0) {
      return;
    }

    final accountId = _accountId;

    if (accountId == null) {
      return;
    }

    List<TransactionLineItemInput>? lineItems;

    if (transaction.type == TransactionType.expense) {
      if (_itemized) {
        try {
          lineItems = _buildLineItemInputs(
            transactionAmount: amount,
          );
        } on ArgumentError catch (error) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.message?.toString() ??
                    'Check the expense items.',
              ),
            ),
          );

          return;
        }
      } else {
        // Explicit empty list means:
        // remove any existing line items.
        lineItems = const <TransactionLineItemInput>[];
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(transactionServiceProvider)
          .updateTransaction(
        transactionId: transaction.id,
        accountId: accountId,
        destinationAccountId:
            transaction.type == TransactionType.transfer
                ? _destinationAccountId
                : null,
        categoryId:
            transaction.type == TransactionType.transfer
                ? null
                : transaction.type == TransactionType.expense &&
                        _itemized
                    ? null
                    : _categoryId,
        amount: amount,
        fee: fee,
        payee:
            transaction.type == TransactionType.transfer
                ? null
                : _cleanText(_payeeController.text),
        note: _cleanText(_noteController.text),
        occurredAt: _occurredAt!,
        lineItems: lineItems,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(
        transactionByIdProvider(widget.transactionId),
      );

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
          _saving = false;
        });
      }
    }
  }

  List<TransactionLineItemInput> _buildLineItemInputs({
    required int transactionAmount,
  }) {
    if (_expenseLines.isEmpty) {
      throw ArgumentError(
        'Add at least one expense item.',
      );
    }

    final inputs = <TransactionLineItemInput>[];
    var total = 0;

    for (var i = 0; i < _expenseLines.length; i++) {
      final line = _expenseLines[i];

      final name = line.nameController.text.trim();

      if (name.isEmpty) {
        throw ArgumentError(
          'Item ${i + 1} needs a name.',
        );
      }

      final categoryId = line.categoryId;

      if (categoryId == null) {
        throw ArgumentError(
          '$name needs a category.',
        );
      }

      final amount = Money.tryParseToMinorUnits(
        line.amountController.text,
      );

      if (amount == null || amount <= 0) {
        throw ArgumentError(
          '$name needs a valid amount.',
        );
      }

      final quantityText =
          line.quantityController.text.trim();

      int? quantity;

      if (quantityText.isNotEmpty) {
        final parsed = double.tryParse(quantityText);

        if (parsed == null || parsed <= 0) {
          throw ArgumentError(
            '$name needs a valid quantity.',
          );
        }

        quantity = Quantity.toStored(parsed);
      }

      total += amount;

      inputs.add(
        TransactionLineItemInput(
          categoryId: categoryId,
          itemDefinitionId: line.itemDefinitionId,
          monthlyPlannedItemId:
              line.monthlyPlannedItemId,
          nameSnapshot: name,
          quantity: quantity,
          unitSnapshot: _cleanText(
            line.unitController.text,
          ),
          amount: amount,
        ),
      );
    }

    if (total != transactionAmount) {
      throw ArgumentError(
        'Expense items total ${Money.formatZmw(total)}, '
        'but the transaction amount is '
        '${Money.formatZmw(transactionAmount)}.',
      );
    }

    return inputs;
  }

  Future<void> _selectDate() async {
    final current = _occurredAt;

    if (current == null) {
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    final changedMonth =
        selected.year != current.year ||
        selected.month != current.month;

    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );

      if (changedMonth) {
        for (final line in _expenseLines) {
          line.monthlyPlannedItemId = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(
      transactionByIdProvider(widget.transactionId),
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
        title: const Text('Edit transaction'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
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
                  return FutureBuilder<
                      List<TransactionLineItem>>(
                    future: _lineItemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState !=
                          ConnectionState.done) {
                        return const _LoadingState();
                      }

                      if (snapshot.hasError) {
                        return const _LoadError();
                      }

                      final lineItems =
                          snapshot.data ??
                          const <TransactionLineItem>[];

                      _initialize(
                        transaction,
                        categories,
                        lineItems,
                      );

                      return _buildForm(
                        context,
                        transaction,
                        accounts,
                      );
                    },
                  );
                },
                loading: () =>
                    const _LoadingState(),
                error: (_, __) =>
                    const _LoadError(),
              );
            },
            loading: () =>
                const _LoadingState(),
            error: (_, __) =>
                const _LoadError(),
          );
        },
        loading: () =>
            const _LoadingState(),
        error: (_, __) =>
            const _LoadError(),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    FinanceTransaction transaction,
    List<FinanceAccount> accounts,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          40,
        ),
        children: [
          _TypeCard(
            type: transaction.type,
          ),

          const SizedBox(height: 16),

          _SectionCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'K ',
                  ),
                  validator: (value) {
                    final amount =
                        Money.tryParseToMinorUnits(
                      value ?? '',
                    );

                    if (amount == null ||
                        amount <= 0) {
                      return 'Enter a valid amount greater than zero';
                    }

                    return null;
                  },
                  onChanged: (_) {
                    if (_itemized) {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _feeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Fee',
                    prefixText: 'K ',
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return null;
                    }

                    final fee =
                        Money.tryParseToMinorUnits(value);

                    if (fee == null || fee < 0) {
                      return 'Enter a valid fee';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText:
                        transaction.type ==
                                TransactionType.transfer
                            ? 'From account'
                            : 'Account',
                  ),
                  items: accounts
                      .map(
                        (account) =>
                            DropdownMenuItem<int>(
                          value: account.id,
                          child: Text(
                            account.name,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _accountId = value;

                      if (_destinationAccountId ==
                          value) {
                        _destinationAccountId = null;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Select an account';
                    }

                    return null;
                  },
                ),

                if (transaction.type ==
                    TransactionType.transfer) ...[
                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    value: _destinationAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'To account',
                    ),
                    items: accounts
                        .where(
                          (account) =>
                              account.id != _accountId,
                        )
                        .map(
                          (account) =>
                              DropdownMenuItem<int>(
                            value: account.id,
                            child: Text(
                              account.name,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _destinationAccountId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Select the destination account';
                      }

                      if (value == _accountId) {
                        return 'Choose a different account';
                      }

                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),

          if (transaction.type ==
              TransactionType.expense) ...[
            const SizedBox(height: 16),

            _ItemizeToggleCard(
              enabled: _itemized,
              onChanged:
                  _saving ? null : _setItemized,
            ),
          ],

          if (transaction.type !=
                  TransactionType.transfer &&
              !(transaction.type ==
                      TransactionType.expense &&
                  _itemized)) ...[
            const SizedBox(height: 16),

            _CategorySection(
              transactionType: transaction.type,
              selectedGroupId: _categoryGroupId,
              selectedCategoryId: _categoryId,
              onGroupChanged: (groupId) {
                setState(() {
                  _categoryGroupId = groupId;
                  _categoryId = null;
                });
              },
              onCategoryChanged: (categoryId) {
                setState(() {
                  _categoryId = categoryId;
                });
              },
            ),
          ],

          if (transaction.type ==
                  TransactionType.expense &&
              _itemized) ...[
            const SizedBox(height: 16),
            _buildItemizedExpenseSection(),
          ],

          const SizedBox(height: 16),

          _SectionCard(
            child: Column(
              children: [
                if (transaction.type !=
                    TransactionType.transfer) ...[
                  TextFormField(
                    controller: _payeeController,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText:
                          transaction.type ==
                                  TransactionType.income
                              ? 'From / payer'
                              : 'Payee',
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            child: InkWell(
              onTap: _saving ? null : _selectDate,
              borderRadius:
                  BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _formatDate(_occurredAt!),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save changes',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedExpenseSection() {
    final transactionAmount =
        Money.tryParseToMinorUnits(
      _amountController.text,
    );

    var itemTotal = 0;

    for (final line in _expenseLines) {
      final amount =
          Money.tryParseToMinorUnits(
        line.amountController.text,
      );

      if (amount != null && amount > 0) {
        itemTotal += amount;
      }
    }

    final difference =
        transactionAmount == null
            ? null
            : transactionAmount - itemTotal;

    return Column(
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expense items',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color:
                                AppTheme.textPrimary,
                            fontWeight:
                                FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : _addExpenseLine,
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Edit how this payment is split across the things you bought.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color:
                          AppTheme.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 16),
              _LineTotalSummary(
                transactionAmount:
                    transactionAmount,
                itemTotal: itemTotal,
                difference: difference,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        ...List.generate(
          _expenseLines.length,
          (index) {
            final line =
                _expenseLines[index];

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: _ExpenseLineEditor(
                key: ValueKey(line.id),
                line: line,
                lineNumber: index + 1,
                occurredAt: _occurredAt!,
                canRemove:
                    _expenseLines.length > 1,
                onRemove: () =>
                    _removeExpenseLine(index),
                onChanged: () {
                  setState(() {});
                },
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String? _cleanText(String value) {
    final cleaned = value.trim();

    return cleaned.isEmpty ? null : cleaned;
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Check the transaction details.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Could not update transaction.';
  }
}

class _ExpenseLineDraft {
  _ExpenseLineDraft() : id = _nextId++;

  _ExpenseLineDraft.fromExisting(
    TransactionLineItem item, {
    int? categoryGroupId,
  }) : id = _nextId++ {
    this.categoryGroupId = categoryGroupId;
    categoryId = item.categoryId;
    itemDefinitionId = item.itemDefinitionId;
    monthlyPlannedItemId =
        item.monthlyPlannedItemId;

    nameController.text = item.nameSnapshot;

    quantityController.text =
        item.quantity == null
            ? ''
            : Quantity.format(item.quantity!);

    unitController.text =
        item.unitSnapshot ?? '';

    amountController.text =
        Money.formatMinorUnits(item.amount);
  }

  static int _nextId = 1;

  final int id;

  final nameController =
      TextEditingController();
  final quantityController =
      TextEditingController();
  final unitController =
      TextEditingController();
  final amountController =
      TextEditingController();

  int? categoryGroupId;
  int? categoryId;
  int? itemDefinitionId;
  int? monthlyPlannedItemId;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    amountController.dispose();
  }
}

class _ItemizeToggleCard
    extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _ItemizeToggleCard({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: enabled,
        onChanged: onChanged,
        title: Text(
          'Itemize expense',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          enabled
              ? 'This expense uses line-item categories for budgeting.'
              : 'Split this payment into individual items and categories.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color:
                    AppTheme.textSecondary,
                height: 1.4,
              ),
        ),
      ),
    );
  }
}

class _LineTotalSummary
    extends StatelessWidget {
  final int? transactionAmount;
  final int itemTotal;
  final int? difference;

  const _LineTotalSummary({
    required this.transactionAmount,
    required this.itemTotal,
    required this.difference,
  });

  @override
  Widget build(BuildContext context) {
    final matches =
        transactionAmount != null &&
        difference == 0;

    String status;

    if (transactionAmount == null) {
      status =
          'Enter the transaction amount above.';
    } else if (difference == 0) {
      status =
          'Items match the transaction amount.';
    } else if (difference! > 0) {
      status =
          '${Money.formatZmw(difference!)} remaining to itemize.';
    } else {
      status =
          'Items exceed the transaction by ${Money.formatZmw(-difference!)}.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Transaction',
            value: transactionAmount == null
                ? '—'
                : Money.formatZmw(
                    transactionAmount!,
                  ),
          ),
          const SizedBox(height: 7),
          _SummaryRow(
            label: 'Items',
            value:
                Money.formatZmw(itemTotal),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                matches
                    ? Icons
                        .check_circle_outline_rounded
                    : Icons
                        .info_outline_rounded,
                size: 17,
                color: matches
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  status,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: matches
                            ? AppTheme.primaryDark
                            : AppTheme
                                .textSecondary,
                        fontWeight:
                            FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      AppTheme.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ExpenseLineEditor
    extends ConsumerStatefulWidget {
  final _ExpenseLineDraft line;
  final int lineNumber;
  final DateTime occurredAt;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ExpenseLineEditor({
    super.key,
    required this.line,
    required this.lineNumber,
    required this.occurredAt,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  ConsumerState<_ExpenseLineEditor>
      createState() =>
          _ExpenseLineEditorState();
}

class _ExpenseLineEditorState
    extends ConsumerState<
        _ExpenseLineEditor> {
  @override
  Widget build(BuildContext context) {
    final line = widget.line;

    return _SectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${widget.lineNumber}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        color:
                            AppTheme.textPrimary,
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.nameController,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Sugar',
            ),
          ),
          const SizedBox(height: 16),
          _LineCategorySelector(
            selectedGroupId:
                line.categoryGroupId,
            selectedCategoryId:
                line.categoryId,
            onGroupChanged: (groupId) {
              setState(() {
                line.categoryGroupId =
                    groupId;
                line.categoryId = null;
                line.itemDefinitionId = null;
                line.monthlyPlannedItemId =
                    null;
              });

              widget.onChanged();
            },
            onCategoryChanged:
                (categoryId) {
              setState(() {
                line.categoryId =
                    categoryId;
                line.itemDefinitionId = null;
                line.monthlyPlannedItemId =
                    null;
              });

              widget.onChanged();
            },
          ),

          if (line.categoryId != null) ...[
            const SizedBox(height: 16),
            _PlannedItemDropdown(
              year: widget.occurredAt.year,
              month: widget.occurredAt.month,
              categoryId: line.categoryId!,
              value:
                  line.monthlyPlannedItemId,
              onChanged: (item) {
                setState(() {
                  line.monthlyPlannedItemId =
                      item?.id;
                  line.itemDefinitionId =
                      item?.itemDefinitionId;

                  if (item != null) {
                    if (line.nameController.text
                        .trim()
                        .isEmpty) {
                      line.nameController.text =
                          item.nameSnapshot;
                    }

                    if (line
                            .quantityController
                            .text
                            .trim()
                            .isEmpty &&
                        item.plannedQuantity !=
                            null) {
                      line.quantityController.text =
                          Quantity.format(
                        item.plannedQuantity!,
                      );
                    }

                    if (line.unitController.text
                            .trim()
                            .isEmpty &&
                        item.unitSnapshot != null) {
                      line.unitController.text =
                          item.unitSnapshot!;
                    }
                  }
                });

                widget.onChanged();
              },
            ),
          ],

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller:
                      line.quantityController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Optional',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller:
                      line.unitController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Unit',
                    hintText:
                        'kg, pack, litre...',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller:
                line.amountController,
            keyboardType:
                const TextInputType
                    .numberWithOptions(
              decimal: true,
            ),
            decoration:
                const InputDecoration(
              labelText: 'Amount',
              prefixText: 'K ',
              hintText: '0.00',
            ),
            onChanged: (_) =>
                widget.onChanged(),
          ),
        ],
      ),
    );
  }
}

class _LineCategorySelector
    extends ConsumerWidget {
  final int? selectedGroupId;
  final int? selectedCategoryId;
  final ValueChanged<int?>
      onGroupChanged;
  final ValueChanged<int?>
      onCategoryChanged;

  const _LineCategorySelector({
    required this.selectedGroupId,
    required this.selectedCategoryId,
    required this.onGroupChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final groupsAsync = ref.watch(
      categoryGroupsProvider(
        CategoryType.expense,
      ),
    );

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Text(
            'No expense categories are available.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color:
                      AppTheme.textSecondary,
                ),
          );
        }

        return Column(
          children: [
            DropdownButtonFormField<int>(
              value: selectedGroupId,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'Category group',
              ),
              hint: const Text(
                'Select a group',
              ),
              items: groups
                  .map(
                    (group) =>
                        DropdownMenuItem<int>(
                      value: group.id,
                      child: Text(
                        group.name,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onGroupChanged,
            ),

            if (selectedGroupId != null) ...[
              const SizedBox(height: 14),
              _CategoryDropdown(
                groupId: selectedGroupId!,
                selectedCategoryId:
                    selectedCategoryId,
                onChanged:
                    onCategoryChanged,
              ),
            ],
          ],
        );
      },
      loading: () =>
          const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) =>
          Text(
        'Could not load expense categories.',
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

class _PlannedItemDropdown
    extends ConsumerWidget {
  final int year;
  final int month;
  final int categoryId;
  final int? value;
  final ValueChanged<MonthlyPlannedItem?>
      onChanged;

  const _PlannedItemDropdown({
    required this.year,
    required this.month,
    required this.categoryId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final itemsAsync = ref.watch(
      plannedItemsProvider(
        (
          year: year,
          month: month,
          categoryId: categoryId,
        ),
      ),
    );

    return itemsAsync.when(
      data: (items) {
        final validValue =
            value != null &&
                    items.any(
                      (item) =>
                          item.id == value,
                    )
                ? value
                : null;

        if (items.isEmpty &&
            validValue == null) {
          return Text(
            'No planned items in this category for this month.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      AppTheme.textSecondary,
                ),
          );
        }

        return DropdownButtonFormField<int?>(
          value: validValue,
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText:
                'Link to budget plan',
            helperText: 'Optional',
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Not linked'),
            ),
            ...items.map(
              (item) =>
                  DropdownMenuItem<int?>(
                value: item.id,
                child: Text(
                  item.nameSnapshot,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }

            MonthlyPlannedItem?
                selected;

            for (final item in items) {
              if (item.id == id) {
                selected = item;
                break;
              }
            }

            onChanged(selected);
          },
        );
      },
      loading: () =>
          const LinearProgressIndicator(),
      error: (error, stackTrace) =>
          Text(
        'Could not load planned items.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(
              color:
                  AppTheme.textSecondary,
            ),
      ),
    );
  }
}

class _CategorySection
    extends ConsumerWidget {
  final TransactionType transactionType;
  final int? selectedGroupId;
  final int? selectedCategoryId;
  final ValueChanged<int?>
      onGroupChanged;
  final ValueChanged<int?>
      onCategoryChanged;

  const _CategorySection({
    required this.transactionType,
    required this.selectedGroupId,
    required this.selectedCategoryId,
    required this.onGroupChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final categoryType =
        transactionType ==
                TransactionType.income
            ? CategoryType.income
            : CategoryType.expense;

    final groupsAsync = ref.watch(
      categoryGroupsProvider(
        categoryType,
      ),
    );

    return _SectionCard(
      child: groupsAsync.when(
        data: (groups) {
          return Column(
            children: [
              DropdownButtonFormField<int?>(
                value: selectedGroupId,
                isExpanded: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Category group',
                ),
                items: [
                  const DropdownMenuItem<
                      int?>(
                    value: null,
                    child: Text(
                      'Uncategorized',
                    ),
                  ),
                  ...groups.map(
                    (group) =>
                        DropdownMenuItem<
                            int?>(
                      value: group.id,
                      child: Text(
                        group.name,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onGroupChanged,
              ),

              if (selectedGroupId != null) ...[
                const SizedBox(height: 18),
                _CategoryDropdown(
                  groupId: selectedGroupId!,
                  selectedCategoryId:
                      selectedCategoryId,
                  onChanged:
                      onCategoryChanged,
                ),
              ],
            ],
          );
        },
        loading: () =>
            const Center(
          child:
              CircularProgressIndicator(),
        ),
        error: (_, __) =>
            Text(
          'Could not load categories.',
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

class _CategoryDropdown
    extends ConsumerWidget {
  final int groupId;
  final int? selectedCategoryId;
  final ValueChanged<int?> onChanged;

  const _CategoryDropdown({
    required this.groupId,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final categoriesAsync = ref.watch(
      categoriesProvider(groupId),
    );

    return categoriesAsync.when(
      data: (categories) {
        return DropdownButtonFormField<int>(
          value: selectedCategoryId,
          isExpanded: true,
          decoration:
              const InputDecoration(
            labelText: 'Category',
          ),
          hint: const Text(
            'Select a category',
          ),
          items: categories
              .map(
                (category) =>
                    DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(
                    category.name,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
      loading: () =>
          const Center(
        child:
            CircularProgressIndicator(),
      ),
      error: (_, __) =>
          Text(
        'Could not load categories.',
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

class _TypeCard extends StatelessWidget {
  final TransactionType type;

  const _TypeCard({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _icon,
            color: AppTheme.primaryDark,
          ),
          const SizedBox(width: 12),
          Text(
            _label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                  color:
                      AppTheme.textPrimary,
                ),
          ),
          const Spacer(),
          Text(
            'Type cannot be changed',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData get _icon {
    switch (type) {
      case TransactionType.income:
        return Icons.south_west_rounded;
      case TransactionType.expense:
        return Icons.north_east_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _SectionCard
    extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: child,
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
      child: Text(
        'Could not load this transaction.',
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

class _MissingTransaction
    extends StatelessWidget {
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
              color:
                  AppTheme.textSecondary,
            ),
      ),
    );
  }
}
