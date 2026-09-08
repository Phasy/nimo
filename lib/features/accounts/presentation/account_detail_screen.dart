import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../application/account_providers.dart';
import 'add_account_screen.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({
    super.key,
    required this.accountId,
  });
  
  Future<void> _confirmDeactivate(
      BuildContext context,
      WidgetRef ref,
      FinanceAccount account,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
            'This will hide "${account.name}" from your active accounts. '
                'Its history will remain preserved.',
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final repository = ref.read(
      accountRepositoryProvider,
    );

    await repository.deactivateAccount(
      account.id,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(
      accountByIdProvider(accountId),
    );

    return accountAsync.when(
      data: (account) {
        if (account == null) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: _AccountNotFound(),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Account'),
            backgroundColor: AppTheme.background,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddAccountScreen(
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
            ],
          ),
          body: _AccountDetailContent(
            account: account,
          ),
        );
      },
      loading: () {
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: _AccountLoadError(),
        );
      },
    );
  }
}

class _AccountDetailContent extends StatelessWidget {
  final FinanceAccount account;

  const _AccountDetailContent({
    required this.account,
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
        _BalanceCard(
          account: account,
        ),

        const SizedBox(height: 28),

        _SectionTitle(
          title: 'ACCOUNT DETAILS',
        ),

        const SizedBox(height: 10),

        _DetailsCard(
          account: account,
        ),

        const SizedBox(height: 28),

        _SectionTitle(
          title: 'TRANSACTIONS',
        ),

        const SizedBox(height: 10),

        const _TransactionsPlaceholder(),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final FinanceAccount account;

  const _BalanceCard({
    required this.account,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  _iconForAccount(account.type),
                  color: AppTheme.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _labelForAccount(account),
                      style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            'CURRENT BALANCE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            Money.formatZmw(account.currentBalance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAccount(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return Icons.account_balance_outlined;

      case AccountType.mobileMoney:
        return Icons.phone_android_rounded;

      case AccountType.cash:
        return Icons.payments_outlined;

      case AccountType.other:
        return Icons.account_balance_wallet_outlined;
    }
  }

  String _labelForAccount(FinanceAccount account) {
    if (account.provider != null && account.provider!.isNotEmpty) {
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

class _DetailsCard extends StatelessWidget {
  final FinanceAccount account;

  const _DetailsCard({
    required this.account,
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
      child: Column(
        children: [
          _DetailRow(
            label: 'Account type',
            value: _accountTypeLabel(account.type),
          ),

          if (account.provider != null &&
              account.provider!.isNotEmpty) ...[
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.border,
            ),
            _DetailRow(
              label: 'Provider',
              value: account.provider!,
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

  String _accountTypeLabel(AccountType type) {
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
        horizontal: 16,
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _TransactionsPlaceholder extends StatelessWidget {
  const _TransactionsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              color: AppTheme.primary.withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.primaryDark,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Transactions for this account will appear here once the ledger is available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountNotFound extends StatelessWidget {
  const _AccountNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 42,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Account not found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This account may no longer be active.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountLoadError extends StatelessWidget {
  const _AccountLoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Something went wrong while loading this account.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}