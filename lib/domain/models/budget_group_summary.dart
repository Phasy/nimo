import 'category_budget.dart';

class BudgetGroupSummary {
  const BudgetGroupSummary({
    required this.groupId,
    required this.name,
    required this.sortOrder,
    required this.categories,
  });

  /// Null only for the virtual Uncategorized group.
  final int? groupId;

  final String name;
  final int sortOrder;

  final List<CategoryBudget> categories;

  int get startingAvailable {
    return categories.fold(
      0,
          (total, category) =>
      total + category.startingAvailable,
    );
  }

  int get assigned {
    return categories.fold(
      0,
          (total, category) =>
      total + category.assigned,
    );
  }

  int get spent {
    return categories.fold(
      0,
          (total, category) =>
      total + category.spent,
    );
  }

  int get available {
    return categories.fold(
      0,
          (total, category) =>
      total + category.available,
    );
  }

  bool get hasOverspending {
    return categories.any(
          (category) => category.isOverspent,
    );
  }
}