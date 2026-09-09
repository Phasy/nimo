class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.groupId,
    required this.name,
    required this.systemKey,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int groupId;
  final String name;
  final String? systemKey;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceCategory copyWith({
    int? id,
    int? groupId,
    String? name,
    String? systemKey,
    bool clearSystemKey = false,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceCategory(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      systemKey: clearSystemKey ? null : systemKey ?? this.systemKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}