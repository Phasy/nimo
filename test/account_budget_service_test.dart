import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/domain/models/budget_settings.dart';
import 'package:nomi/domain/models/finance_account.dart';
import 'package:nomi/domain/repositories/account_repository.dart';
import 'package:nomi/domain/repositories/budget_repository.dart';
import 'package:nomi/services/account_budget_service.dart';

void main() {
  group('AccountBudgetService', () {
    test('uninitialized Budget changes only the account', () async {
      final fixture = _Fixture(initialAssignable: null);

      await fixture.service.updateAccount(fixture.edited(opening: 150000));

      expect(fixture.accounts.account.openingBalance, 150000);
      expect(fixture.accounts.account.currentBalance, 120000);
      expect(fixture.budget.updateCalls, 0);
    });

    test('initialized Budget receives an opening-balance increase once', () async {
      final fixture = _Fixture(initialAssignable: 300000);

      await fixture.service.updateAccount(fixture.edited(opening: 150000));

      expect(fixture.accounts.account.currentBalance, 120000);
      expect(fixture.budget.initialAssignable, 350000);
      expect(fixture.budget.updateCalls, 1);
    });

    test('initialized Budget receives an opening-balance decrease', () async {
      final fixture = _Fixture(initialAssignable: 300000);

      await fixture.service.updateAccount(fixture.edited(opening: 40000));

      expect(fixture.accounts.account.currentBalance, 10000);
      expect(fixture.budget.initialAssignable, 240000);
    });

    test('no-change edit does not alter initial assignable money', () async {
      final fixture = _Fixture(initialAssignable: 300000);

      await fixture.service.updateAccount(fixture.edited(opening: 100000));

      expect(fixture.budget.initialAssignable, 300000);
      expect(fixture.budget.updateCalls, 0);
    });

    test('existing ledger effect in current balance is preserved', () async {
      final fixture = _Fixture(initialAssignable: 300000);

      await fixture.service.updateAccount(fixture.edited(opening: 130000));

      // Original current K700 contains a -K300 ledger effect from opening K1,000.
      expect(fixture.accounts.account.currentBalance, 100000);
      expect(
        fixture.accounts.account.currentBalance -
            fixture.accounts.account.openingBalance,
        -30000,
      );
    });

    test('transaction runner rolls both concepts back when Budget update fails', () async {
      final fixture = _Fixture(initialAssignable: 300000);
      fixture.budget.failUpdates = true;

      await expectLater(
        fixture.service.updateAccount(fixture.edited(opening: 150000)),
        throwsStateError,
      );

      expect(fixture.accounts.account.openingBalance, 100000);
      expect(fixture.accounts.account.currentBalance, 70000);
      expect(fixture.budget.initialAssignable, 300000);
    });
  });
}

class _Fixture {
  _Fixture({required int? initialAssignable})
      : accounts = _FakeAccountRepository(_account()),
        budget = _FakeBudgetRepository(initialAssignable) {
    runner = _RollbackTransactionRunner(accounts, budget);
    service = AccountBudgetService(
      transactionRunner: runner,
      accountRepository: accounts,
      budgetRepository: budget,
    );
  }

  final _FakeAccountRepository accounts;
  final _FakeBudgetRepository budget;
  late final _RollbackTransactionRunner runner;
  late final AccountBudgetService service;

  FinanceAccount edited({required int opening}) => FinanceAccount(
        id: accounts.account.id,
        name: accounts.account.name,
        type: accounts.account.type,
        provider: accounts.account.provider,
        openingBalance: opening,
        currentBalance: accounts.account.currentBalance,
        isActive: accounts.account.isActive,
        createdAt: accounts.account.createdAt,
        updatedAt: DateTime(2026, 9, 2),
      );

  static FinanceAccount _account() => FinanceAccount(
        id: 1,
        name: 'Cash',
        type: AccountType.cash,
        provider: null,
        openingBalance: 100000,
        currentBalance: 70000,
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
}

class _FakeAccountRepository extends Fake implements AccountRepository {
  _FakeAccountRepository(this.account);

  FinanceAccount account;

  @override
  Future<FinanceAccount?> getAccount(int id) async =>
      id == account.id ? account : null;

  @override
  Future<void> updateAccount(FinanceAccount updated) async {
    final difference = updated.openingBalance - account.openingBalance;
    account = FinanceAccount(
      id: updated.id,
      name: updated.name,
      type: updated.type,
      provider: updated.provider,
      openingBalance: updated.openingBalance,
      currentBalance: account.currentBalance + difference,
      isActive: updated.isActive,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    );
  }
}

class _FakeBudgetRepository extends Fake implements BudgetRepository {
  _FakeBudgetRepository(this.initialAssignable);

  int? initialAssignable;
  int updateCalls = 0;
  bool failUpdates = false;

  @override
  Future<BudgetSettings?> getBudgetSettings() async {
    final amount = initialAssignable;
    return amount == null
        ? null
        : BudgetSettings(
            id: 1,
            budgetStartDate: DateTime(2026, 9, 1),
            initialAssignableAmount: amount,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          );
  }

  @override
  Future<void> updateInitialAssignableAmount({required int delta}) async {
    updateCalls++;
    if (failUpdates) {
      throw StateError('Budget update failed.');
    }
    initialAssignable = initialAssignable! + delta;
  }
}

class _RollbackTransactionRunner implements DatabaseTransactionRunner {
  _RollbackTransactionRunner(this.accounts, this.budget);

  final _FakeAccountRepository accounts;
  final _FakeBudgetRepository budget;

  @override
  Future<void> run(Future<void> Function() action) async {
    final oldAccount = accounts.account;
    final oldAssignable = budget.initialAssignable;
    try {
      await action();
    } catch (_) {
      accounts.account = oldAccount;
      budget.initialAssignable = oldAssignable;
      rethrow;
    }
  }
}
