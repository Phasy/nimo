class TransactionLineItem {
  const TransactionLineItem({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.itemDefinitionId,
    required this.monthlyPlannedItemId,
    required this.nameSnapshot,
    required this.quantity,
    required this.unitSnapshot,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Parent Expense transaction.
  final int transactionId;

  /// Expense category that this portion of the transaction
  /// belongs to.
  final int categoryId;

  /// Optional reusable item catalog entry.
  final int? itemDefinitionId;

  /// Optional monthly plan this purchase fulfills.
  ///
  /// Multiple transaction line items may point to the same
  /// monthly plan, which supports partial purchases.
  final int? monthlyPlannedItemId;

  /// Historical description of what was purchased.
  final String nameSnapshot;

  /// Actual purchased quantity using Nomi's fixed scale.
  ///
  /// 1000 = 1
  /// 1500 = 1.5
  ///
  /// Null means quantity was not recorded.
  final int? quantity;

  /// Historical measurement unit.
  final String? unitSnapshot;

  /// Actual line-item cost in ngwee.
  ///
  /// The transaction fee is not included here.
  final int amount;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasQuantity =>
      quantity != null;

  TransactionLineItem copyWith({
    int? id,
    int? transactionId,
    int? categoryId,
    int? itemDefinitionId,
    bool clearItemDefinitionId = false,
    int? monthlyPlannedItemId,
    bool clearMonthlyPlannedItemId = false,
    String? nameSnapshot,
    int? quantity,
    bool clearQuantity = false,
    String? unitSnapshot,
    bool clearUnitSnapshot = false,
    int? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionLineItem(
      id: id ?? this.id,
      transactionId:
      transactionId ?? this.transactionId,
      categoryId: categoryId ?? this.categoryId,
      itemDefinitionId: clearItemDefinitionId
          ? null
          : itemDefinitionId ??
          this.itemDefinitionId,
      monthlyPlannedItemId:
      clearMonthlyPlannedItemId
          ? null
          : monthlyPlannedItemId ??
          this.monthlyPlannedItemId,
      nameSnapshot:
      nameSnapshot ?? this.nameSnapshot,
      quantity: clearQuantity
          ? null
          : quantity ?? this.quantity,
      unitSnapshot: clearUnitSnapshot
          ? null
          : unitSnapshot ?? this.unitSnapshot,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}