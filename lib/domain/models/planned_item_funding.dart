import 'monthly_planned_item.dart';

class PlannedItemFundingAssessment {
  const PlannedItemFundingAssessment({
    required this.knownPlannedTotal,
    required this.startingAvailable,
    required this.assigned,
  });

  final int knownPlannedTotal;
  final int startingAvailable;
  final int assigned;

  int get categoryFunding => startingAvailable + assigned;

  int get shortfall {
    final difference = knownPlannedTotal - categoryFunding;
    return difference > 0 ? difference : 0;
  }

  bool get needsAdditionalFunding => shortfall > 0;

  int get assignedAfterIncrease => assigned + shortfall;
}

class PlannedItemFundingCalculator {
  const PlannedItemFundingCalculator._();

  static PlannedItemFundingAssessment assess({
    required Iterable<MonthlyPlannedItem> existingItems,
    required int? editedItemId,
    required int? proposedPlannedAmount,
    required int startingAvailable,
    required int assigned,
  }) {
    var knownPlannedTotal = proposedPlannedAmount ?? 0;

    for (final item in existingItems) {
      if (item.id == editedItemId) {
        continue;
      }

      knownPlannedTotal += item.plannedAmount ?? 0;
    }

    return PlannedItemFundingAssessment(
      knownPlannedTotal: knownPlannedTotal,
      startingAvailable: startingAvailable,
      assigned: assigned,
    );
  }
}
