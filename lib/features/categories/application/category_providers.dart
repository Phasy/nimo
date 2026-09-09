import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/category_repository_impl.dart';
import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_category.dart';
import '../../../domain/repositories/category_repository.dart';
import '../../accounts/application/account_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);

  return DriftCategoryRepository(database);
});

final categoryInitializationProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);

  await repository.ensureDefaultsExist();
});

final categoryGroupsProvider =
StreamProvider.family<List<CategoryGroup>, CategoryType?>(
      (ref, type) {
    ref.watch(categoryInitializationProvider);

    final repository = ref.watch(categoryRepositoryProvider);

    return repository.watchGroups(
      type: type,
    );
  },
);

final categoriesProvider =
StreamProvider.family<List<FinanceCategory>, int?>(
      (ref, groupId) {
    ref.watch(categoryInitializationProvider);

    final repository = ref.watch(categoryRepositoryProvider);

    return repository.watchCategories(
      groupId: groupId,
    );
  },
);

final categoryByIdProvider =
Provider.family<AsyncValue<FinanceCategory?>, int>(
      (ref, categoryId) {
    final categories = ref.watch(
      categoriesProvider(null),
    );

    return categories.whenData(
          (items) {
        for (final category in items) {
          if (category.id == categoryId) {
            return category;
          }
        }

        return null;
      },
    );
  },
);