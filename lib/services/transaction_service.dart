import '../core/database/app_database.dart';
import '../domain/models/category_group.dart';
import '../domain/models/finance_transaction.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/transaction_line_item_repository.dart';
import '../domain/repositories/transaction_repository.dart';

/// Unsaved line-item data used when creating or editing an Expense.
///
/// This is deliberately separate from TransactionLineItem because a new
/// line item does not yet have a database ID or timestamps.
class TransactionLineItemInput {
  const TransactionLineItemInput({
    required this.categoryId,
    this.itemDefinitionId,
    this.monthlyPlannedItemId,
    required this.nameSnapshot,
    this.quantity,
    this.unitSnapshot,
    required this.amount,
  });

  final int categoryId;

  final int? itemDefinitionId;

  /// Optional link to a planned item for the same budget month/category.
  final int? monthlyPlannedItemId;

  final String nameSnapshot;

  /// Quantity stored using Nomi's fixed x1000 quantity scale.
  final int? quantity;

  final String? unitSnapshot;

  /// Actual line-item amount in ngwee.
  final int amount;
}

class TransactionService {
  final AppDatabase database;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final TransactionLineItemRepository
  transactionLineItemRepository;
  final BudgetRepository budgetRepository;

  TransactionService({
    required this.database,
    required this.transactionRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.transactionLineItemRepository,
    required this.budgetRepository,
  });

  Future<int> createIncome({
    required int accountId,
    int? categoryId,
    required int amount,
    int fee = 0,
    String? payee,
    String? note,
    required DateTime occurredAt,
    TransactionSource source =
        TransactionSource.manual,
    String? externalTransactionId,
  }) async {
    _validateMoney(
      amount: amount,
      fee: fee,
    );

    await _requireActiveAccount(accountId);

    await _validateCategory(
      categoryId: categoryId,
      requiredType: CategoryType.income,
    );

    return database.transaction(() async {
      final transactionId =
      await transactionRepository
          .createTransaction(
        type: TransactionType.income,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        fee: fee,
        payee: payee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId:
        externalTransactionId,
      );

      await accountRepository.adjustCurrentBalance(
        accountId,
        amount - fee,
      );

      return transactionId;
    });
  }

  Future<int> createExpense({
    required int accountId,
    int? categoryId,
    required int amount,
    int fee = 0,
    String? payee,
    String? note,
    required DateTime occurredAt,
    TransactionSource source =
        TransactionSource.manual,
    String? externalTransactionId,
    List<TransactionLineItemInput> lineItems =
    const <TransactionLineItemInput>[],
  }) async {
    _validateMoney(
      amount: amount,
      fee: fee,
    );

    await _requireActiveAccount(accountId);

    await _validateCategory(
      categoryId: categoryId,
      requiredType: CategoryType.expense,
    );

    await _validateExpenseLineItems(
      lineItems: lineItems,
      transactionAmount: amount,
      occurredAt: occurredAt,
    );

    return database.transaction(() async {
      final transactionId =
      await transactionRepository
          .createTransaction(
        type: TransactionType.expense,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        fee: fee,
        payee: payee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId:
        externalTransactionId,
      );

      await _createLineItems(
        transactionId: transactionId,
        lineItems: lineItems,
      );

      await accountRepository.adjustCurrentBalance(
        accountId,
        -(amount + fee),
      );

      return transactionId;
    });
  }

  Future<int> createTransfer({
    required int sourceAccountId,
    required int destinationAccountId,
    required int amount,
    int fee = 0,
    String? note,
    required DateTime occurredAt,
    TransactionSource source =
        TransactionSource.manual,
    String? externalTransactionId,
  }) async {
    _validateMoney(
      amount: amount,
      fee: fee,
    );

    if (sourceAccountId ==
        destinationAccountId) {
      throw ArgumentError(
        'A transfer must use two different accounts.',
      );
    }

    await _requireActiveAccount(sourceAccountId);
    await _requireActiveAccount(
      destinationAccountId,
    );

    return database.transaction(() async {
      final transactionId =
      await transactionRepository
          .createTransaction(
        type: TransactionType.transfer,
        accountId: sourceAccountId,
        destinationAccountId:
        destinationAccountId,
        categoryId: null,
        amount: amount,
        fee: fee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId:
        externalTransactionId,
      );

      await accountRepository.adjustCurrentBalance(
        sourceAccountId,
        -(amount + fee),
      );

      await accountRepository.adjustCurrentBalance(
        destinationAccountId,
        amount,
      );

      return transactionId;
    });
  }

  /// Updates an existing transaction.
  ///
  /// [lineItems] has three different meanings:
  ///
  /// null
  ///   Keep the Expense's existing line items unchanged.
  ///
  /// empty list
  ///   Remove all existing line items and return the Expense to normal
  ///   transaction-category behaviour.
  ///
  /// non-empty list
  ///   Replace all existing line items with the supplied itemization.
  ///
  /// Income and Transfer transactions cannot receive line items.
  Future<void> updateTransaction({
    required int transactionId,
    required int accountId,
    int? destinationAccountId,
    int? categoryId,
    required int amount,
    required int fee,
    String? payee,
    String? note,
    required DateTime occurredAt,
    List<TransactionLineItemInput>? lineItems,
  }) async {
    final existing =
    await transactionRepository
        .getTransaction(transactionId);

    if (existing == null) {
      throw StateError(
        'Transaction $transactionId does not exist.',
      );
    }

    if (existing.isDeleted) {
      throw StateError(
        'Deleted transactions cannot be edited.',
      );
    }

    _validateMoney(
      amount: amount,
      fee: fee,
    );

    await _requireActiveAccount(accountId);

    switch (existing.type) {
      case TransactionType.income:
        if (destinationAccountId != null) {
          throw ArgumentError(
            'Income cannot have a destination account.',
          );
        }

        if (lineItems != null &&
            lineItems.isNotEmpty) {
          throw ArgumentError(
            'Income transactions cannot have line items.',
          );
        }

        await _validateCategory(
          categoryId: categoryId,
          requiredType: CategoryType.income,
        );

        break;

      case TransactionType.expense:
        if (destinationAccountId != null) {
          throw ArgumentError(
            'Expense cannot have a destination account.',
          );
        }

        await _validateCategory(
          categoryId: categoryId,
          requiredType: CategoryType.expense,
        );

        if (lineItems != null) {
          await _validateExpenseLineItems(
            lineItems: lineItems,
            transactionAmount: amount,
            occurredAt: occurredAt,
          );
        }

        break;

      case TransactionType.transfer:
        if (destinationAccountId == null) {
          throw ArgumentError(
            'Transfer requires a destination account.',
          );
        }

        if (accountId ==
            destinationAccountId) {
          throw ArgumentError(
            'A transfer must use two different accounts.',
          );
        }

        if (categoryId != null) {
          throw ArgumentError(
            'Transfers cannot have categories.',
          );
        }

        if (lineItems != null &&
            lineItems.isNotEmpty) {
          throw ArgumentError(
            'Transfers cannot have line items.',
          );
        }

        await _requireActiveAccount(
          destinationAccountId,
        );

        break;
    }

    final updated = existing.copyWith(
      accountId: accountId,
      destinationAccountId:
      destinationAccountId,
      clearDestinationAccountId:
      existing.type !=
          TransactionType.transfer,
      categoryId: categoryId,
      clearCategoryId:
      existing.type ==
          TransactionType.transfer ||
          categoryId == null,
      amount: amount,
      fee: fee,
      payee: payee,
      clearPayee:
      payee == null ||
          payee.trim().isEmpty,
      note: note,
      clearNote:
      note == null ||
          note.trim().isEmpty,
      occurredAt: occurredAt,
      updatedAt: DateTime.now(),
    );

    await database.transaction(() async {
      await _reverseEffect(existing);

      await transactionRepository
          .updateTransaction(updated);

      if (existing.type ==
          TransactionType.expense &&
          lineItems != null) {
        await transactionLineItemRepository
            .deleteLineItemsForTransaction(
          transactionId,
        );

        await _createLineItems(
          transactionId: transactionId,
          lineItems: lineItems,
        );
      }

      await _applyEffect(updated);
    });
  }

  Future<void> deleteTransaction(
      int transactionId,
      ) async {
    final transaction =
    await transactionRepository
        .getTransaction(transactionId);

    if (transaction == null) {
      throw StateError(
        'Transaction $transactionId does not exist.',
      );
    }

    if (transaction.isDeleted) {
      return;
    }

    await database.transaction(() async {
      await _reverseEffect(transaction);

      await transactionRepository.markDeleted(
        transactionId,
      );

      // Deliberately do NOT delete TransactionLineItems here.
      //
      // Transactions are soft-deleted and their historical item detail
      // remains attached to the parent. Budget/price-history queries exclude
      // line items whose parent transaction is deleted.
    });
  }

  Future<void> _createLineItems({
    required int transactionId,
    required List<TransactionLineItemInput>
    lineItems,
  }) async {
    for (final line in lineItems) {
      await transactionLineItemRepository
          .createLineItem(
        transactionId: transactionId,
        categoryId: line.categoryId,
        itemDefinitionId:
        line.itemDefinitionId,
        monthlyPlannedItemId:
        line.monthlyPlannedItemId,
        nameSnapshot:
        line.nameSnapshot.trim(),
        quantity: line.quantity,
        unitSnapshot:
        _cleanOptionalText(
          line.unitSnapshot,
        ),
        amount: line.amount,
      );
    }
  }

  Future<void> _validateExpenseLineItems({
    required List<TransactionLineItemInput>
    lineItems,
    required int transactionAmount,
    required DateTime occurredAt,
  }) async {
    if (lineItems.isEmpty) {
      return;
    }

    var total = 0;

    for (final line in lineItems) {
      final name =
      line.nameSnapshot.trim();

      if (name.isEmpty) {
        throw ArgumentError(
          'Every line item requires a name.',
        );
      }

      if (line.amount <= 0) {
        throw ArgumentError(
          '$name must have an amount greater than zero.',
        );
      }

      if (line.quantity != null &&
          line.quantity! <= 0) {
        throw ArgumentError(
          '$name must have a quantity greater than zero.',
        );
      }

      await _validateCategory(
        categoryId: line.categoryId,
        requiredType: CategoryType.expense,
      );

      if (line.monthlyPlannedItemId != null) {
        await _validatePlannedItemLink(
          line: line,
          occurredAt: occurredAt,
        );
      }

      total += line.amount;
    }

    if (total != transactionAmount) {
      throw ArgumentError(
        'Line items must add up to the transaction amount.',
      );
    }
  }

  Future<void> _validatePlannedItemLink({
    required TransactionLineItemInput line,
    required DateTime occurredAt,
  }) async {
    final plannedItemId =
        line.monthlyPlannedItemId;

    if (plannedItemId == null) {
      return;
    }

    final plannedItem =
    await budgetRepository.getPlannedItem(
      plannedItemId,
    );

    if (plannedItem == null) {
      throw StateError(
        'Planned item $plannedItemId does not exist.',
      );
    }

    if (plannedItem.categoryId !=
        line.categoryId) {
      throw ArgumentError(
        'A line item can only be linked to a planned item in the same category.',
      );
    }

    final transactionBudgetMonth =
    await budgetRepository.getBudgetMonth(
      year: occurredAt.year,
      month: occurredAt.month,
    );

    if (transactionBudgetMonth == null ||
        transactionBudgetMonth.id !=
            plannedItem.budgetMonthId) {
      throw ArgumentError(
        'A line item can only be linked to a planned item from the transaction month.',
      );
    }

    final plannedDefinitionId =
        plannedItem.itemDefinitionId;

    if (plannedDefinitionId != null &&
        line.itemDefinitionId != null &&
        plannedDefinitionId !=
            line.itemDefinitionId) {
      throw ArgumentError(
        'The selected item does not match the linked planned item.',
      );
    }
  }

  Future<void> _applyEffect(
      FinanceTransaction transaction,
      ) async {
    switch (transaction.type) {
      case TransactionType.income:
        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          transaction.amount -
              transaction.fee,
        );

        break;

      case TransactionType.expense:
        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount +
              transaction.fee),
        );

        break;

      case TransactionType.transfer:
        final destinationAccountId =
            transaction.destinationAccountId;

        if (destinationAccountId == null) {
          throw StateError(
            'Transfer ${transaction.id} has no destination account.',
          );
        }

        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount +
              transaction.fee),
        );

        await accountRepository
            .adjustCurrentBalance(
          destinationAccountId,
          transaction.amount,
        );

        break;
    }
  }

  Future<void> _reverseEffect(
      FinanceTransaction transaction,
      ) async {
    switch (transaction.type) {
      case TransactionType.income:
        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount -
              transaction.fee),
        );

        break;

      case TransactionType.expense:
        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          transaction.amount +
              transaction.fee,
        );

        break;

      case TransactionType.transfer:
        final destinationAccountId =
            transaction.destinationAccountId;

        if (destinationAccountId == null) {
          throw StateError(
            'Transfer ${transaction.id} has no destination account.',
          );
        }

        await accountRepository
            .adjustCurrentBalance(
          transaction.accountId,
          transaction.amount +
              transaction.fee,
        );

        await accountRepository
            .adjustCurrentBalance(
          destinationAccountId,
          -transaction.amount,
        );

        break;
    }
  }

  void _validateMoney({
    required int amount,
    required int fee,
  }) {
    if (amount <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero.',
      );
    }

    if (fee < 0) {
      throw ArgumentError(
        'Transaction fee cannot be negative.',
      );
    }
  }

  Future<void> _requireActiveAccount(
      int accountId,
      ) async {
    final account =
    await accountRepository.getAccount(
      accountId,
    );

    if (account == null) {
      throw StateError(
        'Account $accountId does not exist.',
      );
    }

    if (!account.isActive) {
      throw StateError(
        'Account $accountId is inactive.',
      );
    }
  }

  Future<void> _validateCategory({
    required int? categoryId,
    required CategoryType requiredType,
  }) async {
    if (categoryId == null) {
      return;
    }

    final category =
    await categoryRepository.getCategory(
      categoryId,
    );

    if (category == null) {
      throw StateError(
        'Category $categoryId does not exist.',
      );
    }

    if (!category.isActive) {
      throw StateError(
        'Category $categoryId is inactive.',
      );
    }

    final group =
    await categoryRepository.getGroup(
      category.groupId,
    );

    if (group == null) {
      throw StateError(
        'Category group ${category.groupId} does not exist.',
      );
    }

    if (!group.isActive) {
      throw StateError(
        'Category group ${group.id} is inactive.',
      );
    }

    if (group.type != requiredType) {
      throw ArgumentError(
        requiredType == CategoryType.income
            ? 'Income transactions require an income category.'
            : 'Expense transactions require an expense category.',
      );
    }
  }

  String? _cleanOptionalText(
      String? value,
      ) {
    if (value == null) {
      return null;
    }

    final cleaned = value.trim();

    return cleaned.isEmpty
        ? null
        : cleaned;
  }
}