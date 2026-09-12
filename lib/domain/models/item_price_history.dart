import '../../core/utils/quantity.dart';

class ItemPurchaseHistoryEntry {
  const ItemPurchaseHistoryEntry({
    required this.transactionLineItemId,
    required this.transactionId,
    required this.occurredAt,
    required this.payee,
    required this.quantity,
    required this.unit,
    required this.amount,
  });

  final int transactionLineItemId;
  final int transactionId;
  final DateTime occurredAt;
  final String? payee;
  final int? quantity;
  final String? unit;
  final int amount;

  String? get normalizedUnit {
    final value = unit?.trim().toLowerCase();
    return value == null || value.isEmpty ? null : value;
  }

  int? get unitPrice {
    final storedQuantity = quantity;
    if (storedQuantity == null || storedQuantity <= 0 || normalizedUnit == null) {
      return null;
    }

    final numerator = amount * Quantity.scale;
    return ((numerator * 2) + storedQuantity) ~/ (storedQuantity * 2);
  }
}

class ItemPriceHistory {
  const ItemPriceHistory({
    required this.entries,
    required this.latestComparable,
    required this.previousComparable,
  });

  factory ItemPriceHistory.fromEntries(
    Iterable<ItemPurchaseHistoryEntry> source,
  ) {
    final entries = source.toList()
      ..sort((a, b) {
        final dateOrder = b.occurredAt.compareTo(a.occurredAt);
        return dateOrder != 0
            ? dateOrder
            : b.transactionLineItemId.compareTo(a.transactionLineItemId);
      });

    ItemPurchaseHistoryEntry? latest;
    ItemPurchaseHistoryEntry? previous;

    for (final entry in entries) {
      if (entry.unitPrice == null) {
        continue;
      }

      if (latest == null) {
        latest = entry;
        continue;
      }

      if (entry.normalizedUnit == latest.normalizedUnit) {
        previous = entry;
        break;
      }
    }

    return ItemPriceHistory(
      entries: List.unmodifiable(entries),
      latestComparable: latest,
      previousComparable: previous,
    );
  }

  final List<ItemPurchaseHistoryEntry> entries;
  final ItemPurchaseHistoryEntry? latestComparable;
  final ItemPurchaseHistoryEntry? previousComparable;

  bool get isEmpty => entries.isEmpty;

  int? get changeBasisPoints {
    final latest = latestComparable?.unitPrice;
    final previous = previousComparable?.unitPrice;

    if (latest == null || previous == null || previous == 0) {
      return null;
    }

    final difference = latest - previous;
    final magnitude = difference.abs() * 10000;
    final rounded = ((magnitude * 2) + previous) ~/ (previous * 2);
    return difference < 0 ? -rounded : rounded;
  }
}
