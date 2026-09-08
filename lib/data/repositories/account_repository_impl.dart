import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/finance_account.dart';
import '../../domain/repositories/account_repository.dart';

class DriftAccountRepository implements AccountRepository {
  final AppDatabase database;

  DriftAccountRepository(this.database);

  @override
  Stream<List<FinanceAccount>> watchAccounts() {
    final query = database.select(database.accounts)
      ..where((account) => account.isActive.equals(true))
      ..orderBy([
            (account) => OrderingTerm.asc(account.name),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapAccount).toList(),
    );
  }

  @override
  Future<FinanceAccount?> getAccount(int id) async {
    final query = database.select(database.accounts)
      ..where((account) => account.id.equals(id));

    final row = await query.getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapAccount(row);
  }

  @override
  Future<int> createAccount({
    required String name,
    required AccountType type,
    String? provider,
    required int openingBalance,
  }) {
    return database.into(database.accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: _accountTypeToDatabase(type),
        provider: Value(provider),
        openingBalance: Value(openingBalance),
        currentBalance: Value(openingBalance),
      ),
    );
  }

  @override
  Future<void> updateAccount(FinanceAccount account) async {
    await (database.update(database.accounts)
      ..where((row) => row.id.equals(account.id)))
        .write(
      AccountsCompanion(
        name: Value(account.name),
        type: Value(_accountTypeToDatabase(account.type)),
        provider: Value(account.provider),
        openingBalance: Value(account.openingBalance),
        currentBalance: Value(account.currentBalance),
        isActive: Value(account.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deactivateAccount(int id) async {
    await (database.update(database.accounts)
      ..where((account) => account.id.equals(id)))
        .write(
      AccountsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  FinanceAccount _mapAccount(Account account) {
    return FinanceAccount(
      id: account.id,
      name: account.name,
      type: _accountTypeFromDatabase(account.type),
      provider: account.provider,
      openingBalance: account.openingBalance,
      currentBalance: account.currentBalance,
      isActive: account.isActive,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  AccountType _accountTypeFromDatabase(String value) {
    switch (value) {
      case 'bank':
        return AccountType.bank;

      case 'mobile_money':
        return AccountType.mobileMoney;

      case 'cash':
        return AccountType.cash;

      default:
        return AccountType.other;
    }
  }

  String _accountTypeToDatabase(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 'bank';

      case AccountType.mobileMoney:
        return 'mobile_money';

      case AccountType.cash:
        return 'cash';

      case AccountType.other:
        return 'other';
    }
  }
}