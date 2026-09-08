import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../application/account_providers.dart';
import 'add_account_screen.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final totalBalanceAsync = ref.watch(totalAccountBalanceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Accounts'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return _EmptyAccounts(onAddAccount: () => _openAddAccount(context));
          }

          return _AccountsList(
            accounts: accounts,
            totalBalance: totalBalanceAsync.value ?? 0,
          );
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Something went wrong while loading your accounts.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddAccount(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openAddAccount(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddAccountScreen()));
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onAddAccount;

  const _EmptyAccounts({required this.onAddAccount});

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
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No accounts yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add where your money currently lives — bank, mobile money, cash, or another account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  final List<FinanceAccount> accounts;
  final int totalBalance;

  const _AccountsList({required this.accounts, required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    final bankAccounts = accounts
        .where((account) => account.type == AccountType.bank)
        .toList();

    final mobileMoneyAccounts = accounts
        .where((account) => account.type == AccountType.mobileMoney)
        .toList();

    final cashAccounts = accounts
        .where((account) => account.type == AccountType.cash)
        .toList();

    final otherAccounts = accounts
        .where((account) => account.type == AccountType.other)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _TotalMoneyCard(
          totalBalance: totalBalance,
          accountCount: accounts.length,
        ),

        const SizedBox(height: 30),

        if (bankAccounts.isNotEmpty) ...[
          _AccountGroup(title: 'BANK', accounts: bankAccounts),
          const SizedBox(height: 26),
        ],

        if (mobileMoneyAccounts.isNotEmpty) ...[
          _AccountGroup(title: 'MOBILE MONEY', accounts: mobileMoneyAccounts),
          const SizedBox(height: 26),
        ],

        if (cashAccounts.isNotEmpty) ...[
          _AccountGroup(title: 'CASH', accounts: cashAccounts),
          const SizedBox(height: 26),
        ],

        if (otherAccounts.isNotEmpty)
          _AccountGroup(title: 'OTHER', accounts: otherAccounts),
      ],
    );
  }
}

class _TotalMoneyCard extends StatelessWidget {
  final int totalBalance;
  final int accountCount;

  const _TotalMoneyCard({
    required this.totalBalance,
    required this.accountCount,
  });

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
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 21,
                  color: AppTheme.primaryDark,
                ),
              ),
              const Spacer(),
              Text(
                accountCount == 1
                    ? '1 active account'
                    : '$accountCount active accounts',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'TOTAL MONEY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Money.formatZmw(totalBalance),
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
}

class _AccountGroup extends StatelessWidget {
  final String title;
  final List<FinanceAccount> accounts;

  const _AccountGroup({required this.title, required this.accounts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < accounts.length; index++) ...[
                _AccountGroupRow(
                  account: accounts[index],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccountDetailScreen(
                          accountId: accounts[index].id,
                        ),
                      ),
                    );
                  },
                ),
                if (index < accounts.length - 1)
                  const Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 16,
                    color: AppTheme.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountGroupRow extends StatelessWidget {
  final FinanceAccount account;
  final VoidCallback onTap;

  const _AccountGroupRow({
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
    onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _labelForAccount(account),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              Money.formatZmw(account.currentBalance),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
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
