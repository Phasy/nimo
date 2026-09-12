import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/core/database/app_database.dart';
import 'package:nomi/data/repositories/transaction_line_item_repository_impl.dart';

void main() {
  test('active purchase history excludes soft-deleted parent transactions', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final accountId = await database.into(database.accounts).insert(
      AccountsCompanion.insert(name: 'Cash', type: 'cash'),
    );
    final groupId = await database.into(database.categoryGroups).insert(
      CategoryGroupsCompanion.insert(name: 'Needs', type: 'expense'),
    );
    final categoryId = await database.into(database.categories).insert(
      CategoriesCompanion.insert(groupId: groupId, name: 'Groceries'),
    );
    final itemDefinitionId = await database.into(database.itemDefinitions).insert(
      ItemDefinitionsCompanion.insert(name: 'Sugar'),
    );

    final activeTransactionId = await database.into(database.transactions).insert(
      TransactionsCompanion.insert(
        type: 'expense',
        accountId: accountId,
        amount: 12400,
        occurredAt: DateTime(2026, 9, 3),
      ),
    );
    final deletedTransactionId = await database.into(database.transactions).insert(
      TransactionsCompanion.insert(
        type: 'expense',
        accountId: accountId,
        amount: 19200,
        occurredAt: DateTime(2026, 9, 11),
        isDeleted: const Value(true),
      ),
    );

    await database.into(database.transactionLineItems).insert(
      TransactionLineItemsCompanion.insert(
        transactionId: activeTransactionId,
        categoryId: categoryId,
        itemDefinitionId: Value(itemDefinitionId),
        nameSnapshot: 'Sugar',
        quantity: const Value(2000),
        unitSnapshot: const Value('kg'),
        amount: 12400,
      ),
    );
    await database.into(database.transactionLineItems).insert(
      TransactionLineItemsCompanion.insert(
        transactionId: deletedTransactionId,
        categoryId: categoryId,
        itemDefinitionId: Value(itemDefinitionId),
        nameSnapshot: 'Sugar',
        quantity: const Value(3000),
        unitSnapshot: const Value('kg'),
        amount: 19200,
      ),
    );

    final history = await DriftTransactionLineItemRepository(database)
        .getActivePurchaseHistory(itemDefinitionId: itemDefinitionId);

    expect(history, hasLength(1));
    expect(history.single.transactionId, activeTransactionId);
  });
}
