class MonthlyPlannedItem {
  const MonthlyPlannedItem({
    required this.id,
    required this.budgetMonthId,
    required this.categoryId,
    required this.itemDefinitionId,
    required this.nameSnapshot,
    required this.plannedQuantity,
    required this.unitSnapshot,
    required this.plannedAmount,
    required this.isCompleted,
    required this.sortOrder,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  final int budgetMonthId;
  final int categoryId;

  /// Optional reusable catalog entry.
  ///
  /// Null means this was created as an ad-hoc monthly item.
  final int? itemDefinitionId;

  /// Historical item name captured when the plan was created.
  final String nameSnapshot;

  /// Quantity stored using Nomi's fixed quantity scale.
  ///
  /// Scale:
  ///
  /// 1000 = 1
  /// 1500 = 1.5
  /// 250  = 0.25
  ///
  /// Null means no quantity was specified.
  final int? plannedQuantity;

  /// Historical measurement unit for this plan.
  final String? unitSnapshot;

  /// Planned total amount in ngwee.
  ///
  /// Null means the price/cost is currently unknown.
  final int? plannedAmount;

  /// Manual completion state.
  ///
  /// Actual purchase fulfillment will also be derivable from
  /// linked transaction line items.
  final bool isCompleted;

  final int sortOrder;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasKnownPrice =>
      plannedAmount != null;

  bool get hasQuantity =>
      plannedQuantity != null;

  MonthlyPlannedItem copyWith({
    int? id,
    int? budgetMonthId,
    int? categoryId,
    int? itemDefinitionId,
    bool clearItemDefinitionId = false,
    String? nameSnapshot,
    int? plannedQuantity,
    bool clearPlannedQuantity = false,
    String? unitSnapshot,
    bool clearUnitSnapshot = false,
    int? plannedAmount,
    bool clearPlannedAmount = false,
    bool? isCompleted,
    int? sortOrder,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyPlannedItem(
      id: id ?? this.id,
      budgetMonthId:
      budgetMonthId ?? this.budgetMonthId,
      categoryId: categoryId ?? this.categoryId,
      itemDefinitionId: clearItemDefinitionId
          ? null
          : itemDefinitionId ??
          this.itemDefinitionId,
      nameSnapshot:
      nameSnapshot ?? this.nameSnapshot,
      plannedQuantity: clearPlannedQuantity
          ? null
          : plannedQuantity ??
          this.plannedQuantity,
      unitSnapshot: clearUnitSnapshot
          ? null
          : unitSnapshot ?? this.unitSnapshot,
      plannedAmount: clearPlannedAmount
          ? null
          : plannedAmount ??
          this.plannedAmount,
      isCompleted:
      isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      note: clearNote ? null : note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}