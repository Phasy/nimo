import '../models/transaction_line_item.dart';
import '../models/item_price_history.dart';

abstract class TransactionLineItemRepository {
  Stream<List<TransactionLineItem>>
  watchLineItemsForTransaction(
      int transactionId,
      );

  Future<List<TransactionLineItem>>
  getLineItemsForTransaction(
      int transactionId,
      );

  /// Retrieves line items for multiple transactions in one operation.
  ///
  /// Used heavily by budget calculations so we don't issue one database
  /// query per Expense transaction.
  Future<List<TransactionLineItem>>
  getLineItemsForTransactions(
      List<int> transactionIds,
      );

  Future<TransactionLineItem?> getLineItem(int id);

  Future<int> createLineItem({
    required int transactionId,
    required int categoryId,
    int? itemDefinitionId,
    int? monthlyPlannedItemId,
    required String nameSnapshot,
    int? quantity,
    String? unitSnapshot,
    required int amount,
  });

  Future<void> updateLineItem(
      TransactionLineItem item,
      );

  Future<void> deleteLineItem(int id);

  Future<void> deleteLineItemsForTransaction(
      int transactionId,
      );

  Future<List<TransactionLineItem>>
  getLineItemsForPlannedItem(
      int monthlyPlannedItemId,
      );

  Future<List<TransactionLineItem>>
  getLineItemsForItemDefinition(
      int itemDefinitionId,
      );

  Future<List<ItemPurchaseHistoryEntry>> getActivePurchaseHistory({
    int? itemDefinitionId,
    int? monthlyPlannedItemId,
  });
}
