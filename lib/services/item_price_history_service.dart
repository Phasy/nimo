import '../domain/models/item_price_history.dart';
import '../domain/models/monthly_planned_item.dart';
import '../domain/repositories/transaction_line_item_repository.dart';

class ItemPriceHistoryService {
  const ItemPriceHistoryService({required this.lineItemRepository});

  final TransactionLineItemRepository lineItemRepository;

  Future<ItemPriceHistory> buildForPlannedItem(
    MonthlyPlannedItem plannedItem,
  ) async {
    final entries = plannedItem.itemDefinitionId == null
        ? await lineItemRepository.getActivePurchaseHistory(
            monthlyPlannedItemId: plannedItem.id,
          )
        : await lineItemRepository.getActivePurchaseHistory(
            itemDefinitionId: plannedItem.itemDefinitionId,
          );

    return ItemPriceHistory.fromEntries(entries);
  }
}
