import 'package:flutter_test/flutter_test.dart';
import 'package:nomi/domain/models/monthly_planned_item.dart';
import 'package:nomi/domain/models/planned_item_funding.dart';

void main() {
  group('PlannedItemFundingCalculator', () {
    test(
      'does not report a shortfall when rollover and Assigned fund plan',
      () {
        final result = PlannedItemFundingCalculator.assess(
          existingItems: [_item(id: 1, amount: 30000)],
          editedItemId: null,
          proposedPlannedAmount: 20000,
          startingAvailable: 30000,
          assigned: 20000,
        );

        expect(result.knownPlannedTotal, 50000);
        expect(result.categoryFunding, 50000);
        expect(result.shortfall, 0);
        expect(result.needsAdditionalFunding, isFalse);
      },
    );

    test('calculates the exact additional assignment required', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [_item(id: 1, amount: 55000)],
        editedItemId: null,
        proposedPlannedAmount: 15000,
        startingAvailable: 10000,
        assigned: 50000,
      );

      expect(result.knownPlannedTotal, 70000);
      expect(result.categoryFunding, 60000);
      expect(result.shortfall, 10000);
      expect(result.assignedAfterIncrease, 60000);
    });

    test('unknown prices do not contribute to the known total', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [
          _item(id: 1, amount: 10000),
          _item(id: 2, amount: null),
          _item(id: 3, amount: 20000),
        ],
        editedItemId: null,
        proposedPlannedAmount: null,
        startingAvailable: 0,
        assigned: 30000,
      );

      expect(result.knownPlannedTotal, 30000);
      expect(result.shortfall, 0);
    });

    test('editing replaces the prior amount instead of double-counting it', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [
          _item(id: 1, amount: 30000),
          _item(id: 2, amount: 25000),
        ],
        editedItemId: 1,
        proposedPlannedAmount: 45000,
        startingAvailable: 10000,
        assigned: 50000,
      );

      expect(result.knownPlannedTotal, 70000);
      expect(result.shortfall, 10000);
    });

    test('known to unknown removes only the edited item from known total', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [
          _item(id: 1, amount: 30000),
          _item(id: 2, amount: 25000),
        ],
        editedItemId: 1,
        proposedPlannedAmount: null,
        startingAvailable: 0,
        assigned: 80000,
      );

      expect(result.knownPlannedTotal, 25000);
      expect(result.shortfall, 0);
      expect(result.assignedAfterIncrease, 80000);
    });

    test('a price decrease never proposes lowering Assigned', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [
          _item(id: 1, amount: 30000),
          _item(id: 2, amount: 50000),
        ],
        editedItemId: 1,
        proposedPlannedAmount: 10000,
        startingAvailable: 0,
        assigned: 80000,
      );

      expect(result.knownPlannedTotal, 60000);
      expect(result.shortfall, 0);
      expect(result.assignedAfterIncrease, 80000);
    });

    test('unknown to known can create a funding shortfall', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [
          _item(id: 1, amount: null),
          _item(id: 2, amount: 45000),
        ],
        editedItemId: 1,
        proposedPlannedAmount: 35000,
        startingAvailable: 0,
        assigned: 50000,
      );

      expect(result.knownPlannedTotal, 80000);
      expect(result.shortfall, 30000);
      expect(result.assignedAfterIncrease, 80000);
    });

    test('actual spending cannot affect planning capacity', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: const [],
        editedItemId: null,
        proposedPlannedAmount: 50000,
        startingAvailable: 0,
        assigned: 50000,
      );

      expect(result.categoryFunding, 50000);
      expect(result.shortfall, 0);
    });

    test('an already underfunded plan reports the full current shortfall', () {
      final result = PlannedItemFundingCalculator.assess(
        existingItems: [_item(id: 1, amount: 70000)],
        editedItemId: null,
        proposedPlannedAmount: 10000,
        startingAvailable: 0,
        assigned: 50000,
      );

      expect(result.knownPlannedTotal, 80000);
      expect(result.shortfall, 30000);
      expect(result.assignedAfterIncrease, 80000);
    });
  });
}

MonthlyPlannedItem _item({required int id, required int? amount}) {
  final timestamp = DateTime(2026, 9, 1);

  return MonthlyPlannedItem(
    id: id,
    budgetMonthId: 1,
    categoryId: 1,
    itemDefinitionId: null,
    nameSnapshot: 'Item $id',
    plannedQuantity: null,
    unitSnapshot: null,
    plannedAmount: amount,
    isCompleted: false,
    sortOrder: id,
    note: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
