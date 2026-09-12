class Quantity {
  Quantity._();

  static const int scale = 1000;

  /// Converts a user-facing quantity into its stored integer value.
  ///
  /// Examples:
  /// 1.0  -> 1000
  /// 1.5  -> 1500
  /// 0.25 -> 250
  static int toStored(num value) {
    return (value * scale).round();
  }

  /// Converts the stored integer quantity back into its numeric value.
  ///
  /// Examples:
  /// 1000 -> 1.0
  /// 1500 -> 1.5
  /// 250  -> 0.25
  static double fromStored(int value) {
    return value / scale;
  }

  /// Formats a stored quantity without unnecessary trailing zeros.
  ///
  /// Examples:
  /// 1000 -> "1"
  /// 1500 -> "1.5"
  /// 1250 -> "1.25"
  /// 125  -> "0.125"
  static String format(int value) {
    final whole = value ~/ scale;
    final remainder = value.abs() % scale;

    if (remainder == 0) {
      return whole.toString();
    }

    final fractional =
    remainder.toString().padLeft(3, '0');

    final trimmed =
    fractional.replaceFirst(RegExp(r'0+$'), '');

    if (value < 0 && whole == 0) {
      return '-0.$trimmed';
    }

    return '$whole.$trimmed';
  }
}