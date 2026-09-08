class Money {
  const Money._();

  /// Converts user-entered ZMW text into integer ngwee.
  ///
  /// Examples:
  ///  "10"       -> 1000
  ///  "10.5"     -> 1050
  ///  "10.50"    -> 1050
  ///  "1,250.75" -> 125075
  ///
  /// Returns null when the input is invalid.
  static int? tryParseToMinorUnits(String input) {
    var value = input.trim().replaceAll(',', '');

    if (value.isEmpty) {
      return null;
    }

    // Allow an optional leading minus sign, digits,
    // and no more than two decimal places.
    if (!RegExp(r'^-?\d+(\.\d{0,2})?$').hasMatch(value)) {
      return null;
    }

    final isNegative = value.startsWith('-');

    if (isNegative) {
      value = value.substring(1);
    }

    final parts = value.split('.');

    final wholePart = int.parse(parts[0]);

    var fractionalPart = 0;

    if (parts.length == 2 && parts[1].isNotEmpty) {
      final fraction = parts[1];

      fractionalPart = fraction.length == 1
          ? int.parse(fraction) * 10
          : int.parse(fraction);
    }

    final minorUnits = (wholePart * 100) + fractionalPart;

    return isNegative ? -minorUnits : minorUnits;
  }

  /// Formats integer ngwee as a ZMW amount without the currency prefix.
  ///
  /// Examples:
  ///  1000    -> "10.00"
  ///  1050    -> "10.50"
  ///  125075  -> "1,250.75"
  static String formatMinorUnits(int minorUnits) {
    final absolute = minorUnits.abs();

    final whole = absolute ~/ 100;
    final fraction = absolute % 100;

    final formattedWhole = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );

    final formattedFraction = fraction.toString().padLeft(2, '0');

    return '$formattedWhole.$formattedFraction';
  }

  static String formatZmw(int minorUnits) {
    final sign = minorUnits < 0 ? '-' : '';

    return '${sign}K${formatMinorUnits(minorUnits)}';
  }
}