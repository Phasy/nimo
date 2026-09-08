import 'package:flutter/material.dart';

import '../utils/money.dart';

class MoneyText extends StatelessWidget {
  final int amount;
  final TextStyle? style;
  final bool showPlus;
  final bool showMinus;

  const MoneyText({
    super.key,
    required this.amount,
    this.style,
    this.showPlus = false,
    this.showMinus = false,
  });

  @override
  Widget build(BuildContext context) {
    String prefix = '';

    if (showPlus && amount > 0) {
      prefix = '+';
    } else if (showMinus && amount > 0) {
      prefix = '-';
    } else if (amount < 0) {
      prefix = '-';
    }

    return Text(
      '${prefix}K${Money.formatMinorUnits(amount)}',
      style: style,
    );
  }
}