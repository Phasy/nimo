enum TransactionType {
  income,
  expense,
  transfer,
}

extension TransactionTypeX on TransactionType {
  String get value {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
    }
  }

  static TransactionType fromValue(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      default:
        throw ArgumentError(
          'Unknown transaction type: $value',
        );
    }
  }
}

enum TransactionSource {
  manual,
  sms,
}

extension TransactionSourceX on TransactionSource {
  String get value {
    switch (this) {
      case TransactionSource.manual:
        return 'manual';
      case TransactionSource.sms:
        return 'sms';
    }
  }

  static TransactionSource fromValue(String value) {
    switch (value) {
      case 'manual':
        return TransactionSource.manual;
      case 'sms':
        return TransactionSource.sms;
      default:
        throw ArgumentError(
          'Unknown transaction source: $value',
        );
    }
  }
}

class FinanceTransaction {
  final int id;

  final TransactionType type;

  /// Primary account affected by the transaction.
  ///
  /// Income:
  /// Money enters this account.
  ///
  /// Expense:
  /// Money leaves this account.
  ///
  /// Transfer:
  /// This is the source account.
  final int accountId;

  /// Only populated for transfers.
  ///
  /// Money enters this account.
  final int? destinationAccountId;

  /// Nullable because transactions may remain uncategorized.
  ///
  /// Must be null for transfers.
  final int? categoryId;

  /// Principal amount in minor units (ngwee).
  ///
  /// Always stored as a positive integer.
  final int amount;

  /// Additional transaction cost in minor units.
  ///
  /// Stored separately from [amount].
  /// Must be zero or positive.
  final int fee;

  final String? payee;
  final String? note;

  /// When the financial event actually occurred.
  final DateTime occurredAt;

  /// How the transaction entered Nomi.
  final TransactionSource source;

  /// Provider/bank transaction ID when one exists.
  ///
  /// Manual transactions will normally leave this null.
  final String? externalTransactionId;

  /// Transactions are soft-deleted so historical IDs and
  /// imported transaction references remain preserved.
  final bool isDeleted;

  final DateTime createdAt;
  final DateTime updatedAt;

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.amount,
    this.fee = 0,
    this.payee,
    this.note,
    required this.occurredAt,
    this.source = TransactionSource.manual,
    this.externalTransactionId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;

  bool get isExpense => type == TransactionType.expense;

  bool get isTransfer => type == TransactionType.transfer;

  FinanceTransaction copyWith({
    int? id,
    TransactionType? type,
    int? accountId,
    int? destinationAccountId,
    bool clearDestinationAccountId = false,
    int? categoryId,
    bool clearCategoryId = false,
    int? amount,
    int? fee,
    String? payee,
    bool clearPayee = false,
    String? note,
    bool clearNote = false,
    DateTime? occurredAt,
    TransactionSource? source,
    String? externalTransactionId,
    bool clearExternalTransactionId = false,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      destinationAccountId: clearDestinationAccountId
          ? null
          : destinationAccountId ?? this.destinationAccountId,
      categoryId:
      clearCategoryId ? null : categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      payee: clearPayee ? null : payee ?? this.payee,
      note: clearNote ? null : note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      externalTransactionId: clearExternalTransactionId
          ? null
          : externalTransactionId ?? this.externalTransactionId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}