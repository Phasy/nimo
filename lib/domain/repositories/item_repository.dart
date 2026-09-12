import '../models/item_definition.dart';

abstract class ItemRepository {
  Stream<List<ItemDefinition>> watchItems({
    int? defaultCategoryId,
  });

  Future<List<ItemDefinition>> getItems({
    int? defaultCategoryId,
  });

  Future<ItemDefinition?> getItem(int id);

  Future<int> createItem({
    required String name,
    int? defaultCategoryId,
    String? defaultUnit,
  });

  Future<void> updateItem(
      ItemDefinition item,
      );

  Future<void> deactivateItem(int id);

  Future<bool> itemNameExists({
    required String name,
    int? excludingItemId,
  });
}