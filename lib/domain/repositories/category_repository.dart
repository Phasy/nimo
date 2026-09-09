import '../models/category_group.dart';
import '../models/finance_category.dart';

abstract class CategoryRepository {
  Stream<List<CategoryGroup>> watchGroups({
    CategoryType? type,
  });

  Stream<List<FinanceCategory>> watchCategories({
    int? groupId,
  });

  Future<CategoryGroup?> getGroup(int id);

  Future<FinanceCategory?> getCategory(int id);

  Future<int> createGroup({
    required String name,
    required CategoryType type,
    String? systemKey,
    required int sortOrder,
  });

  Future<int> createCategory({
    required int groupId,
    required String name,
    String? systemKey,
    required int sortOrder,
  });

  Future<void> updateGroup(CategoryGroup group);

  Future<void> updateCategory(FinanceCategory category);

  Future<void> deactivateGroup(int id);

  Future<void> deactivateCategory(int id);

  Future<void> reorderGroups(List<int> orderedGroupIds);

  Future<void> reorderCategories(
      int groupId,
      List<int> orderedCategoryIds,
      );

  Future<void> ensureDefaultsExist();

  Future<bool> groupNameExists({
    required String name,
    required CategoryType type,
    int? excludingGroupId,
  });

  Future<bool> categoryNameExists({
    required String name,
    required int groupId,
    int? excludingCategoryId,
  });

  Future<void> moveCategory({
    required FinanceCategory category,
    required int newGroupId,
    required String name,
  });
}