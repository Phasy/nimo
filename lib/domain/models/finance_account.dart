enum AccountType {
  bank,
  mobileMoney,
  cash,
  other,
}

class FinanceAccount {
  final int id;
  final String name;
  final AccountType type;
  final String? provider;

  final int openingBalance;
  final int currentBalance;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  const FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.provider,
    required this.openingBalance,
    required this.currentBalance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}