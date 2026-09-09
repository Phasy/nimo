import '../core/database/app_database.dart';
import '../domain/models/category_group.dart';
import '../domain/models/finance_transaction.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/transaction_repository.dart';

class TransactionService {
  final AppDatabase database;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;

  TransactionService({
    required this.database,
    required this.transactionRepository,
    required this.accountRepository,
    required this.categoryRepository,
  });

  Future<int> createIncome({
    required int accountId,
    int? categoryId,
    required int amount,
    int fee = 0,
    String? payee,
    String? note,
    required DateTime occurredAt,
    TransactionSource source = TransactionSource.manual,
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
      await transactionRepository.createTransaction(
        type: TransactionType.income,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        fee: fee,
        payee: payee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId: externalTransactionId,
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
    TransactionSource source = TransactionSource.manual,
    String? externalTransactionId,
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

    return database.transaction(() async {
      final transactionId =
      await transactionRepository.createTransaction(
        type: TransactionType.expense,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        fee: fee,
        payee: payee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId: externalTransactionId,
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
    TransactionSource source = TransactionSource.manual,
    String? externalTransactionId,
  }) async {
    _validateMoney(
      amount: amount,
      fee: fee,
    );

    if (sourceAccountId == destinationAccountId) {
      throw ArgumentError(
        'A transfer must use two different accounts.',
      );
    }

    await _requireActiveAccount(sourceAccountId);
    await _requireActiveAccount(destinationAccountId);

    return database.transaction(() async {
      final transactionId =
      await transactionRepository.createTransaction(
        type: TransactionType.transfer,
        accountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        categoryId: null,
        amount: amount,
        fee: fee,
        note: note,
        occurredAt: occurredAt,
        source: source,
        externalTransactionId: externalTransactionId,
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
  }) async {
    final existing =
    await transactionRepository.getTransaction(transactionId);

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

        break;

      case TransactionType.transfer:
        if (destinationAccountId == null) {
          throw ArgumentError(
            'Transfer requires a destination account.',
          );
        }

        if (accountId == destinationAccountId) {
          throw ArgumentError(
            'A transfer must use two different accounts.',
          );
        }

        if (categoryId != null) {
          throw ArgumentError(
            'Transfers cannot have categories.',
          );
        }

        await _requireActiveAccount(destinationAccountId);

        break;
    }

    final updated = existing.copyWith(
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      clearDestinationAccountId:
      existing.type != TransactionType.transfer,
      categoryId: categoryId,
      clearCategoryId:
      existing.type == TransactionType.transfer ||
          categoryId == null,
      amount: amount,
      fee: fee,
      payee: payee,
      clearPayee: payee == null || payee.trim().isEmpty,
      note: note,
      clearNote: note == null || note.trim().isEmpty,
      occurredAt: occurredAt,
      updatedAt: DateTime.now(),
    );

    await database.transaction(() async {
      await _reverseEffect(existing);

      await transactionRepository.updateTransaction(updated);

      await _applyEffect(updated);
    });
  }

  Future<void> deleteTransaction(
      int transactionId,
      ) async {
    final transaction =
    await transactionRepository.getTransaction(transactionId);

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
    });
  }

  Future<void> _applyEffect(
      FinanceTransaction transaction,
      ) async {
    switch (transaction.type) {
      case TransactionType.income:
        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          transaction.amount - transaction.fee,
        );

        break;

      case TransactionType.expense:
        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount + transaction.fee),
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

        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount + transaction.fee),
        );

        await accountRepository.adjustCurrentBalance(
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
        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          -(transaction.amount - transaction.fee),
        );

        break;

      case TransactionType.expense:
        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          transaction.amount + transaction.fee,
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

        await accountRepository.adjustCurrentBalance(
          transaction.accountId,
          transaction.amount + transaction.fee,
        );

        await accountRepository.adjustCurrentBalance(
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
    await accountRepository.getAccount(accountId);

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
    await categoryRepository.getCategory(categoryId);

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
    await categoryRepository.getGroup(category.groupId);

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
}