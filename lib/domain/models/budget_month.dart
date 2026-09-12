class BudgetMonth {
  const BudgetMonth({
    required this.id,
    required this.year,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int year;

  /// Calendar month from 1 to 12.
  final int month;

  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get firstDay =>
      DateTime(year, month);

  DateTime get firstDayOfNextMonth =>
      DateTime(year, month + 1);

  BudgetMonth copyWith({
    int? id,
    int? year,
    int? month,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetMonth(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}