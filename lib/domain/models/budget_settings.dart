class BudgetSettings {
  const BudgetSettings({
    required this.id,
    required this.budgetStartDate,
    required this.initialAssignableAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Exact point at which Nomi's budgeting system begins.
  ///
  /// Transactions before this point are not included in budget
  /// calculations because their effects are already represented
  /// by the initial account-balance snapshot.
  final DateTime budgetStartDate;

  /// Total money owned when budgeting was initialized.
  ///
  /// Stored in minor currency units (ngwee).
  final int initialAssignableAmount;

  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetSettings copyWith({
    int? id,
    DateTime? budgetStartDate,
    int? initialAssignableAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetSettings(
      id: id ?? this.id,
      budgetStartDate:
      budgetStartDate ?? this.budgetStartDate,
      initialAssignableAmount:
      initialAssignableAmount ??
          this.initialAssignableAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}