import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../application/account_providers.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final FinanceAccount? account;

  const AddAccountScreen({super.key, this.account});

  bool get isEditing => account != null;

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  AccountType _type = AccountType.bank;
  String? _provider;

  bool _saving = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    if (account != null) {
      _nameController.text = account.name;
      _balanceController.text = Money.formatMinorUnits(account.openingBalance);

      _type = account.type;
      _provider = account.provider;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountInNgwee = Money.tryParseToMinorUnits(_balanceController.text);

    if (amountInNgwee == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final repository = ref.read(accountRepositoryProvider);

      if (_isEditing) {
        final existingAccount = widget.account!;

        await repository.updateAccount(
          FinanceAccount(
            id: existingAccount.id,
            name: _nameController.text.trim(),
            type: _type,
            provider: _type == AccountType.mobileMoney ? _provider : null,
            openingBalance: amountInNgwee,

            // Transactions do not exist yet, so the current balance
            // continues to mirror the opening balance.
            //
            // Once the transaction ledger is introduced, editing an
            // opening balance must use proper adjustment/reconciliation
            // rules instead.
            currentBalance: existingAccount.currentBalance,

            isActive: existingAccount.isActive,
            createdAt: existingAccount.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await repository.createAccount(
          name: _nameController.text.trim(),
          type: _type,
          provider: _type == AccountType.mobileMoney ? _provider : null,
          openingBalance: amountInNgwee,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit account' : 'Add account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account name',
                hintText: 'e.g. Zanaco',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an account name';
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            DropdownButtonFormField<AccountType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Account type'),
              items: const [
                DropdownMenuItem(value: AccountType.bank, child: Text('Bank')),
                DropdownMenuItem(
                  value: AccountType.mobileMoney,
                  child: Text('Mobile money'),
                ),
                DropdownMenuItem(value: AccountType.cash, child: Text('Cash')),
                DropdownMenuItem(
                  value: AccountType.other,
                  child: Text('Other'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;

                  if (_type != AccountType.mobileMoney) {
                    _provider = null;
                  }
                });
              },
            ),

            if (_type == AccountType.mobileMoney) ...[
              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                value: _provider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: const [
                  DropdownMenuItem(value: 'MTN MoMo', child: Text('MTN MoMo')),
                  DropdownMenuItem(
                    value: 'Airtel Money',
                    child: Text('Airtel Money'),
                  ),
                  DropdownMenuItem(
                    value: 'Zamtel Money',
                    child: Text('Zamtel Money'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                validator: (value) {
                  if (_type == AccountType.mobileMoney && value == null) {
                    return 'Select a provider';
                  }

                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _provider = value;
                  });
                },
              ),
            ],

            const SizedBox(height: 18),

            TextFormField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _isEditing ? 'Opening balance' : 'Opening balance',
                prefixText: 'K ',
                hintText: '0.00',
                helperText: _isEditing
                    ? 'Changing this currently changes the account balance too.'
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the opening balance';
                }

                final amount = Money.tryParseToMinorUnits(value);

                if (amount == null) {
                  return 'Enter a valid amount with up to 2 decimal places';
                }

                if (amount < 0) {
                  return 'Balance cannot be negative';
                }

                return null;
              },
            ),

            const SizedBox(height: 30),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Add account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
