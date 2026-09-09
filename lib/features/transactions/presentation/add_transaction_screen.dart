import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../accounts/application/account_providers.dart';
import '../application/transaction_providers.dart';
import '../../../domain/models/category_group.dart';
import '../../categories/application/category_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType initialType;

  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;

  int? _accountId;
  int? _destinationAccountId;
  int? _categoryGroupId;
  int? _categoryId;

  late DateTime _occurredAt;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _type = widget.initialType;
    _occurredAt = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _payeeController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  void _changeType(TransactionType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;

      _categoryGroupId = null;
      _categoryId = null;

      if (_type != TransactionType.transfer) {
        _destinationAccountId = null;
      }
    });
  }

  Future<void> _save() async {
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
      final service = ref.read(
        transactionServiceProvider,
      );

      switch (_type) {
        case TransactionType.expense:
          await service.createExpense(
            accountId: accountId,
            categoryId: _categoryId,
            amount: amount,
            fee: fee,
            payee: _cleanText(_payeeController.text),
            note: _cleanText(_noteController.text),
            occurredAt: _occurredAt,
          );

          break;

        case TransactionType.income:
          await service.createIncome(
            accountId: accountId,
            categoryId: _categoryId,
            amount: amount,
            fee: fee,
            payee: _cleanText(_payeeController.text),
            note: _cleanText(_noteController.text),
            occurredAt: _occurredAt,
          );

          break;

        case TransactionType.transfer:
          final destinationAccountId =
              _destinationAccountId;

          if (destinationAccountId == null) {
            throw ArgumentError(
              'Select a destination account.',
            );
          }

          await service.createTransfer(
            sourceAccountId: accountId,
            destinationAccountId:
            destinationAccountId,
            amount: amount,
            fee: fee,
            note: _cleanText(_noteController.text),
            occurredAt: _occurredAt,
          );

          break;
      }

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
          _saving = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
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
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add transaction'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const _NoAccountsState();
          }

          return _buildForm(
            context,
            accounts,
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Something went wrong while loading your accounts.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context,
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
          _TypeSelector(
            selected: _type,
            onChanged: _changeType,
          ),

          const SizedBox(height: 24),

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
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter an amount';
                    }

                    final amount =
                    Money.tryParseToMinorUnits(value);

                    if (amount == null) {
                      return 'Enter a valid amount';
                    }

                    if (amount <= 0) {
                      return 'Amount must be greater than zero';
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
                    helperText:
                    'Leave blank if there was no fee.',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return null;
                    }

                    final fee =
                    Money.tryParseToMinorUnits(value);

                    if (fee == null) {
                      return 'Enter a valid fee';
                    }

                    if (fee < 0) {
                      return 'Fee cannot be negative';
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
                  decoration: InputDecoration(
                    labelText: _type ==
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
                  validator: (value) {
                    if (value == null) {
                      return _type ==
                          TransactionType.transfer
                          ? 'Select the source account'
                          : 'Select an account';
                    }

                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _accountId = value;

                      if (_destinationAccountId ==
                          value) {
                        _destinationAccountId = null;
                      }
                    });
                  },
                ),

                if (_type ==
                    TransactionType.transfer) ...[
                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    value: _destinationAccountId,
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
                    validator: (value) {
                      if (_type !=
                          TransactionType.transfer) {
                        return null;
                      }

                      if (value == null) {
                        return 'Select the destination account';
                      }

                      if (value == _accountId) {
                        return 'Choose a different account';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _destinationAccountId =
                            value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          if (_type !=
              TransactionType.transfer) ...[
            const SizedBox(height: 16),

            _CategorySection(
              transactionType: _type,
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

          const SizedBox(height: 16),

          _SectionCard(
            child: Column(
              children: [
                if (_type !=
                    TransactionType.transfer) ...[
                  TextFormField(
                    controller: _payeeController,
                    textCapitalization:
                    TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText:
                      _type == TransactionType.income
                          ? 'From / payer'
                          : 'Payee',
                      hintText:
                      _type == TransactionType.income
                          ? 'e.g. Employer'
                          : 'e.g. Shoprite',
                    ),
                  ),

                  const SizedBox(height: 18),
                ],

                TextFormField(
                  controller: _noteController,
                  textCapitalization:
                  TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Optional',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            child: InkWell(
              onTap: _saving ? null : _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
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
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
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
                            _formatDate(_occurredAt),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              color:
                              AppTheme.textPrimary,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
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
              padding: const EdgeInsets.symmetric(
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
                  : Text(_saveLabel),
            ),
          ),
        ],
      ),
    );
  }

  String get _saveLabel {
    switch (_type) {
      case TransactionType.expense:
        return 'Add expense';

      case TransactionType.income:
        return 'Add income';

      case TransactionType.transfer:
        return 'Make transfer';
    }
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

    return 'Could not save the transaction.';
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'Expense',
              selected:
              selected == TransactionType.expense,
              onTap: () => onChanged(
                TransactionType.expense,
              ),
            ),
          ),
          Expanded(
            child: _TypeButton(
              label: 'Income',
              selected:
              selected == TransactionType.income,
              onTap: () => onChanged(
                TransactionType.income,
              ),
            ),
          ),
          Expanded(
            child: _TypeButton(
              label: 'Transfer',
              selected:
              selected == TransactionType.transfer,
              onTap: () => onChanged(
                TransactionType.transfer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 160,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(
            color: selected
                ? Colors.white
                : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: child,
    );
  }
}

class _NoAccountsState extends StatelessWidget {
  const _NoAccountsState();

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
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add an account first',
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
              'Transactions need an account so Nomi knows where the money came from or went.',
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
    transactionType == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;

    final groupsAsync = ref.watch(
      categoryGroupsProvider(categoryType),
    );

    return _SectionCard(
      child: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Text(
              'No categories are available.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: AppTheme.textSecondary,
              ),
            );
          }

          return Column(
            children: [
              DropdownButtonFormField<int?>(
                value: selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Category group',
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  ...groups.map(
                        (group) => DropdownMenuItem<int?>(
                      value: group.id,
                      child: Text(
                        group.name,
                        overflow: TextOverflow.ellipsis,
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
                  onChanged: onCategoryChanged,
                ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 12,
          ),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Text(
          'Could not load categories.',
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

class _CategoryDropdown extends ConsumerWidget {
  final int groupId;
  final int? selectedCategoryId;
  final ValueChanged<int?> onChanged;

  const _CategoryDropdown({
    required this.groupId,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      categoriesProvider(groupId),
    );

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Text(
            'This group has no categories.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: AppTheme.textSecondary,
            ),
          );
        }

        return DropdownButtonFormField<int>(
          value: selectedCategoryId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
          ),
          hint: const Text('Select a category'),
          items: categories
              .map(
                (category) =>
                DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          )
              .toList(),
          onChanged: onChanged,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Text(
        'Could not load this category group.',
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