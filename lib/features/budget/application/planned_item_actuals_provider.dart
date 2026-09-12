import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/transaction_line_item.dart';
import '../../../domain/models/item_price_history.dart';
import '../../../services/item_price_history_service.dart';
import '../../transactions/application/transaction_providers.dart';
import 'budget_providers.dart';

/// Actual expense line items explicitly linked to a monthly planned item.
///
/// The repository already excludes line items whose parent transaction
/// is soft-deleted, so this represents live actual spending/history.
final plannedItemActualsProvider = FutureProvider.autoDispose
    .family<List<TransactionLineItem>, int>(
  (ref, monthlyPlannedItemId) {
    ref.watch(transactionsProvider);
    final repository = ref.watch(
      transactionLineItemRepositoryProvider,
    );

    return repository.getLineItemsForPlannedItem(
      monthlyPlannedItemId,
    );
  },
);

final itemPriceHistoryServiceProvider = Provider<ItemPriceHistoryService>(
  (ref) => ItemPriceHistoryService(
    lineItemRepository: ref.watch(transactionLineItemRepositoryProvider),
  ),
);

final plannedItemPriceHistoryProvider =
    FutureProvider.autoDispose.family<ItemPriceHistory, int>(
  (ref, monthlyPlannedItemId) async {
    ref.watch(transactionsProvider);
    final plannedItem = await ref
        .watch(budgetRepositoryProvider)
        .getPlannedItem(monthlyPlannedItemId);

    if (plannedItem == null) {
      throw StateError('Planned item $monthlyPlannedItemId does not exist.');
    }

    return ref
        .watch(itemPriceHistoryServiceProvider)
        .buildForPlannedItem(plannedItem);
  },
);
