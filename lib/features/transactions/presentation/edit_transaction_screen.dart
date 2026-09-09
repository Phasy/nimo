import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../accounts/application/account_providers.dart';
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

  FinanceTransaction? _transaction;

  int? _accountId;
  int? _destinationAccountId;
  int? _categoryGroupId;
  int? _categoryId;

  DateTime? _occurredAt;

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _payeeController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  void _initialize(
      FinanceTransaction transaction,
      List<dynamic> categories,
      ) {
    if (_initialized) {
      return;
    }

    _transaction = transaction;

    _accountId = transaction.accountId;
    _destinationAccountId =
        transaction.destinationAccountId;
    _categoryId = transaction.categoryId;
    _occurredAt = transaction.occurredAt;

    _amountController.text =
        Money.formatMinorUnits(
          transaction.amount,
        );

    _feeController.text =
    transaction.fee == 0
        ? ''
        : Money.formatMinorUnits(
      transaction.fee,
    );

    _payeeController.text =
        transaction.payee ?? '';

    _noteController.text =
        transaction.note ?? '';

    if (transaction.categoryId != null) {
      for (final category in categories) {
        if (category.id == transaction.categoryId) {
          _categoryGroupId = category.groupId;
          break;
        }
      }
    }

    _initialized = true;
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
        transaction.type ==
            TransactionType.transfer
            ? _destinationAccountId
            : null,
        categoryId:
        transaction.type ==
            TransactionType.transfer
            ? null
            : _categoryId,
        amount: amount,
        fee: fee,
        payee:
        transaction.type ==
            TransactionType.transfer
            ? null
            : _cleanText(
          _payeeController.text,
        ),
        note: _cleanText(
          _noteController.text,
        ),
        occurredAt: _occurredAt!,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(
        transactionByIdProvider(
          widget.transactionId,
        ),
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

    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
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
                  _initialize(
                    transaction,
                    categories,
                  );

                  return _buildForm(
                    context,
                    transaction,
                    accounts,
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
                    Money.tryParseToMinorUnits(
                      value,
                    );

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
                        _destinationAccountId =
                            value;
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

          if (transaction.type !=
              TransactionType.transfer) ...[
            const SizedBox(height: 16),

            _CategorySection(
              transactionType:
              transaction.type,
              selectedGroupId:
              _categoryGroupId,
              selectedCategoryId:
              _categoryId,
              onGroupChanged: (groupId) {
                setState(() {
                  _categoryGroupId = groupId;
                  _categoryId = null;
                });
              },
              onCategoryChanged:
                  (categoryId) {
                setState(() {
                  _categoryId =
                      categoryId;
                });
              },
            ),
          ],

          const SizedBox(height: 16),

          _SectionCard(
            child: Column(
              children: [
                if (transaction.type !=
                    TransactionType.transfer) ...[
                  TextFormField(
                    controller:
                    _payeeController,
                    textCapitalization:
                    TextCapitalization.words,
                    decoration:
                    InputDecoration(
                      labelText:
                      transaction.type ==
                          TransactionType
                              .income
                          ? 'From / payer'
                          : 'Payee',
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                TextFormField(
                  controller:
                  _noteController,
                  maxLines: 3,
                  textCapitalization:
                  TextCapitalization.sentences,
                  decoration:
                  const InputDecoration(
                    labelText: 'Note',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            child: InkWell(
              onTap:
              _saving ? null : _selectDate,
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
                      color:
                      AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _formatDate(
                          _occurredAt!,
                        ),
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
                      Icons
                          .chevron_right_rounded,
                      color:
                      AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          FilledButton(
            onPressed:
            _saving ? null : _save,
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

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String? _cleanText(String value) {
    final cleaned = value.trim();

    return cleaned.isEmpty
        ? null
        : cleaned;
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

class _CategorySection extends ConsumerWidget {
  final TransactionType transactionType;
  final int? selectedGroupId;
  final int? selectedCategoryId;

  final ValueChanged<int?> onGroupChanged;
  final ValueChanged<int?> onCategoryChanged;

  const _CategorySection({
    required this.transactionType,
    required this.selectedGroupId,
    required this.selectedCategoryId,
    required this.onGroupChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    child:
                    Text('Uncategorized'),
                  ),
                  ...groups.map(
                        (group) =>
                        DropdownMenuItem<
                            int?>(
                          value: group.id,
                          child: Text(
                            group.name,
                            overflow: TextOverflow
                                .ellipsis,
                          ),
                        ),
                  ),
                ],
                onChanged: onGroupChanged,
              ),

              if (selectedGroupId !=
                  null) ...[
                const SizedBox(height: 18),

                _CategoryDropdown(
                  groupId:
                  selectedGroupId!,
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
        error: (_, __) => Text(
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
          hint:
          const Text('Select a category'),
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
      error: (_, __) => Text(
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
      padding:
      const EdgeInsets.all(18),
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

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(18),
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