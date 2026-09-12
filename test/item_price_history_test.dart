import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/domain/models/item_price_history.dart';
import 'package:nomi/domain/models/monthly_planned_item.dart';
import 'package:nomi/domain/repositories/transaction_line_item_repository.dart';
import 'package:nomi/services/item_price_history_service.dart';

void main() {
  group('ItemPriceHistory', () {
    test('calculates and rounds unit price with integer arithmetic', () {
      expect(_entry(id: 1, amount: 12400, quantity: 2000).unitPrice, 6200);
      expect(_entry(id: 2, amount: 1, quantity: 2000).unitPrice, 1);
      expect(_entry(id: 3, amount: 100, quantity: 3000).unitPrice, 33);
    });

    test('sorts purchases newest-first and compares newest two compatible', () {
      final history = ItemPriceHistory.fromEntries([
        _entry(id: 1, amount: 12400, quantity: 2000, day: 3),
        _entry(id: 2, amount: 19200, quantity: 3000, day: 11),
      ]);

      expect(history.entries.map((entry) => entry.transactionLineItemId), [2, 1]);
      expect(history.latestComparable?.unitPrice, 6400);
      expect(history.previousComparable?.unitPrice, 6200);
      expect(history.changeBasisPoints, 323);
    });

    test('missing quantity cannot contribute to unit-price comparison', () {
      final missing = _entry(id: 2, amount: 19200, quantity: null, day: 11);
      final history = ItemPriceHistory.fromEntries([
        _entry(id: 1, amount: 12400, quantity: 2000, day: 3),
        missing,
      ]);

      expect(missing.unitPrice, isNull);
      expect(history.latestComparable?.transactionLineItemId, 1);
      expect(history.previousComparable, isNull);
    });

    test('missing unit cannot produce a comparable unit price', () {
      final entry = ItemPurchaseHistoryEntry(
        transactionLineItemId: 1,
        transactionId: 1,
        occurredAt: DateTime(2026, 9, 1),
        payee: null,
        quantity: 2000,
        unit: null,
        amount: 12400,
      );

      expect(entry.unitPrice, isNull);
    });

    test('incompatible units are not compared', () {
      final history = ItemPriceHistory.fromEntries([
        _entry(id: 1, amount: 12400, quantity: 2000, unit: 'kg', day: 3),
        _entry(id: 2, amount: 19200, quantity: 3000, unit: 'pack', day: 11),
      ]);

      expect(history.latestComparable?.normalizedUnit, 'pack');
      expect(history.previousComparable, isNull);
      expect(history.changeBasisPoints, isNull);
    });

    test('unit comparison trims whitespace and ignores case', () {
      final history = ItemPriceHistory.fromEntries([
        _entry(id: 1, amount: 12400, quantity: 2000, unit: ' KG ', day: 3),
        _entry(id: 2, amount: 19200, quantity: 3000, unit: 'kg', day: 11),
      ]);

      expect(history.previousComparable, isNotNull);
      expect(history.changeBasisPoints, 323);
    });

    test('empty source produces the no-history state', () {
      final history = ItemPriceHistory.fromEntries(const []);

      expect(history.isEmpty, isTrue);
      expect(history.latestComparable, isNull);
    });
  });

  group('ItemPriceHistoryService identity', () {
    test('uses stable itemDefinitionId across purchases when available', () async {
      final repository = _FakeLineItemRepository();
      final service = ItemPriceHistoryService(lineItemRepository: repository);

      await service.buildForPlannedItem(_plannedItem(itemDefinitionId: 42));

      expect(repository.requestedItemDefinitionId, 42);
      expect(repository.requestedPlannedItemId, isNull);
    });

    test('falls back only to direct planned-item links', () async {
      final repository = _FakeLineItemRepository();
      final service = ItemPriceHistoryService(lineItemRepository: repository);

      await service.buildForPlannedItem(_plannedItem(itemDefinitionId: null));

      expect(repository.requestedItemDefinitionId, isNull);
      expect(repository.requestedPlannedItemId, 7);
    });
  });
}

ItemPurchaseHistoryEntry _entry({
  required int id,
  required int amount,
  required int? quantity,
  String unit = 'kg',
  int day = 1,
}) {
  return ItemPurchaseHistoryEntry(
    transactionLineItemId: id,
    transactionId: id,
    occurredAt: DateTime(2026, 9, day),
    payee: 'Shop',
    quantity: quantity,
    unit: unit,
    amount: amount,
  );
}

MonthlyPlannedItem _plannedItem({required int? itemDefinitionId}) {
  final date = DateTime(2026, 9, 1);
  return MonthlyPlannedItem(
    id: 7,
    budgetMonthId: 1,
    categoryId: 1,
    itemDefinitionId: itemDefinitionId,
    nameSnapshot: 'Sugar',
    plannedQuantity: 2000,
    unitSnapshot: 'kg',
    plannedAmount: 12400,
    isCompleted: false,
    sortOrder: 0,
    note: null,
    createdAt: date,
    updatedAt: date,
  );
}

class _FakeLineItemRepository extends Fake
    implements TransactionLineItemRepository {
  int? requestedItemDefinitionId;
  int? requestedPlannedItemId;

  @override
  Future<List<ItemPurchaseHistoryEntry>> getActivePurchaseHistory({
    int? itemDefinitionId,
    int? monthlyPlannedItemId,
  }) async {
    requestedItemDefinitionId = itemDefinitionId;
    requestedPlannedItemId = monthlyPlannedItemId;
    return const [];
  }
}
