enum CategoryType {
  expense,
  income,
}

class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.systemKey,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final CategoryType type;
  final String? systemKey;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryGroup copyWith({
    int? id,
    String? name,
    CategoryType? type,
    String? systemKey,
    bool clearSystemKey = false,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      systemKey: clearSystemKey ? null : systemKey ?? this.systemKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}