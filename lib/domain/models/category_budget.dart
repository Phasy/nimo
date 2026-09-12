class CategoryBudget {
  const CategoryBudget({
    required this.categoryId,
    required this.groupId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.startingAvailable,
    required this.assigned,
    required this.spent,
  });

  /// Null only for Nomi's virtual Uncategorized budget row.
  final int? categoryId;

  /// Null only for the virtual Uncategorized row.
  final int? groupId;

  final String name;
  final int sortOrder;

  /// Real categories retain their actual active state.
  ///
  /// Uncategorized is considered active for display purposes.
  final bool isActive;

  /// Money carried into this month.
  ///
  /// startingAvailable
  /// =
  /// cumulative assignments before this month
  /// -
  /// cumulative spending before this month
  final int startingAvailable;

  /// Net amount deliberately assigned during this month.
  final int assigned;

  /// Spending occurring during this month.
  final int spent;

  int get available =>
      startingAvailable + assigned - spent;

  int get planningCapacity => startingAvailable + assigned;

  bool get isOverspent => available < 0;

  bool get isUncategorized => categoryId == null;

  bool get hasActivity =>
      startingAvailable != 0 ||
          assigned != 0 ||
          spent != 0;
}
