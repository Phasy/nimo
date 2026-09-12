class BudgetAllocation {
  const BudgetAllocation({
    required this.id,
    required this.budgetMonthId,
    required this.categoryId,
    required this.assignedAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int budgetMonthId;
  final int categoryId;

  /// Net amount assigned to this category during this month.
  ///
  /// Stored in minor currency units (ngwee).
  ///
  /// May be:
  /// - positive when money is assigned
  /// - zero when nothing is assigned
  /// - negative when money is removed
  final int assignedAmount;

  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetAllocation copyWith({
    int? id,
    int? budgetMonthId,
    int? categoryId,
    int? assignedAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetAllocation(
      id: id ?? this.id,
      budgetMonthId:
      budgetMonthId ?? this.budgetMonthId,
      categoryId: categoryId ?? this.categoryId,
      assignedAmount:
      assignedAmount ?? this.assignedAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}