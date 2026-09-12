class ItemDefinition {
  const ItemDefinition({
    required this.id,
    required this.name,
    required this.defaultCategoryId,
    required this.defaultUnit,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Reusable item/service name.
  ///
  /// Examples:
  /// Sugar
  /// Cooking Oil
  /// Electricity
  /// Internet
  /// Bus Fare
  final String name;

  /// Suggested category when this item is added to a plan.
  ///
  /// This is not a permanent historical category assignment.
  final int? defaultCategoryId;

  /// Suggested measurement unit.
  ///
  /// Examples:
  /// kg
  /// litre
  /// piece
  /// pack
  /// month
  /// trip
  final String? defaultUnit;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  ItemDefinition copyWith({
    int? id,
    String? name,
    int? defaultCategoryId,
    bool clearDefaultCategoryId = false,
    String? defaultUnit,
    bool clearDefaultUnit = false,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultCategoryId: clearDefaultCategoryId
          ? null
          : defaultCategoryId ??
          this.defaultCategoryId,
      defaultUnit: clearDefaultUnit
          ? null
          : defaultUnit ?? this.defaultUnit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}