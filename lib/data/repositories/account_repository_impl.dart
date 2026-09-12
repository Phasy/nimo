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
      ..where(
            (account) => account.isActive.equals(true),
      )
      ..orderBy([
            (account) => OrderingTerm.asc(
          account.name,
        ),
      ]);

    return query.watch().map(
          (rows) => rows
          .map(_mapAccount)
          .toList(),
    );
  }

  @override
  Stream<List<FinanceAccount>> watchAllAccounts() {
    final query = database.select(database.accounts)
      ..orderBy([
            (account) => OrderingTerm.asc(
          account.name,
        ),
      ]);

    return query.watch().map(
          (rows) => rows
          .map(_mapAccount)
          .toList(),
    );
  }

  @override
  Future<FinanceAccount?> getAccount(
      int id,
      ) async {
    final query = database.select(
      database.accounts,
    )
      ..where(
            (account) => account.id.equals(id),
      );

    final row =
    await query.getSingleOrNull();

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
    return database
        .into(database.accounts)
        .insert(
      AccountsCompanion.insert(
        name: name,
        type: _accountTypeToDatabase(
          type,
        ),
        provider: Value(provider),
        openingBalance:
        Value(openingBalance),
        currentBalance:
        Value(openingBalance),
      ),
    );
  }

  @override
  Future<void> updateAccount(
      FinanceAccount account,
      ) async {
    await database.transaction(() async {
      final query =
      database.select(database.accounts)
        ..where(
              (row) => row.id.equals(
            account.id,
          ),
        );

      final existing =
      await query.getSingleOrNull();

      if (existing == null) {
        throw StateError(
          'Account ${account.id} does not exist.',
        );
      }

      /*
       * The transaction ledger is authoritative.
       *
       * Editing an opening balance must NOT reset
       * currentBalance.
       *
       * Example:
       *
       * old opening = K1,000
       * current     = K700
       *
       * new opening = K1,200
       *
       * difference  = +K200
       * new current = K900
       */
      final openingBalanceDifference =
          account.openingBalance -
              existing.openingBalance;

      final newCurrentBalance =
          existing.currentBalance +
              openingBalanceDifference;

      await (database.update(
        database.accounts,
      )
        ..where(
              (row) => row.id.equals(
            account.id,
          ),
        ))
          .write(
        AccountsCompanion(
          name: Value(account.name),
          type: Value(
            _accountTypeToDatabase(
              account.type,
            ),
          ),
          provider: Value(
            account.provider,
          ),
          openingBalance: Value(
            account.openingBalance,
          ),
          currentBalance: Value(
            newCurrentBalance,
          ),
          isActive: Value(
            account.isActive,
          ),
          updatedAt: Value(
            DateTime.now(),
          ),
        ),
      );
    });
  }

  @override
  Future<void> deactivateAccount(
      int id,
      ) async {
    final updatedRows =
    await (database.update(
      database.accounts,
    )
      ..where(
            (account) =>
            account.id.equals(id),
      ))
        .write(
      AccountsCompanion(
        isActive:
        const Value(false),
        updatedAt: Value(
          DateTime.now(),
        ),
      ),
    );

    if (updatedRows == 0) {
      throw StateError(
        'Account $id does not exist.',
      );
    }
  }

  @override
  Future<void> reactivateAccount(
      int id,
      ) async {
    final updatedRows =
    await (database.update(
      database.accounts,
    )
      ..where(
            (account) =>
            account.id.equals(id),
      ))
        .write(
      AccountsCompanion(
        isActive:
        const Value(true),
        updatedAt: Value(
          DateTime.now(),
        ),
      ),
    );

    if (updatedRows == 0) {
      throw StateError(
        'Account $id does not exist.',
      );
    }
  }

  @override
  Future<void> adjustCurrentBalance(
      int accountId,
      int delta,
      ) async {
    /*
     * IMPORTANT:
     *
     * Do not:
     *
     *   read balance
     *   calculate in Dart
     *   write balance
     *
     * Transaction operations may modify multiple
     * accounts inside the same database transaction.
     *
     * Updating with:
     *
     *   current_balance = current_balance + delta
     *
     * keeps the balance adjustment atomic at the
     * SQLite level.
     */
    final updatedRows =
    await database.customUpdate(
      '''
      UPDATE accounts
      SET current_balance = current_balance + ?,
          updated_at = ?
      WHERE id = ?
      ''',
      variables: [
        Variable<int>(delta),
        Variable<DateTime>(
          DateTime.now(),
        ),
        Variable<int>(accountId),
      ],
      updates: {
        database.accounts,
      },
    );

    if (updatedRows == 0) {
      throw StateError(
        'Account $accountId does not exist.',
      );
    }
  }

  @override
  Future<void> updateOpeningBalance({
    required int accountId,
    required int openingBalance,
  }) async {
    await database.transaction(() async {
      final query =
      database.select(database.accounts)
        ..where(
              (row) => row.id.equals(
            accountId,
          ),
        );

      final account =
      await query.getSingleOrNull();

      if (account == null) {
        throw StateError(
          'Account $accountId does not exist.',
        );
      }

      final difference =
          openingBalance -
              account.openingBalance;

      final newCurrentBalance =
          account.currentBalance +
              difference;

      await (database.update(
        database.accounts,
      )
        ..where(
              (row) => row.id.equals(
            accountId,
          ),
        ))
          .write(
        AccountsCompanion(
          openingBalance: Value(
            openingBalance,
          ),
          currentBalance: Value(
            newCurrentBalance,
          ),
          updatedAt: Value(
            DateTime.now(),
          ),
        ),
      );
    });
  }

  FinanceAccount _mapAccount(
      Account account,
      ) {
    return FinanceAccount(
      id: account.id,
      name: account.name,
      type: _accountTypeFromDatabase(
        account.type,
      ),
      provider: account.provider,
      openingBalance:
      account.openingBalance,
      currentBalance:
      account.currentBalance,
      isActive: account.isActive,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  AccountType _accountTypeFromDatabase(
      String value,
      ) {
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

  String _accountTypeToDatabase(
      AccountType type,
      ) {
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