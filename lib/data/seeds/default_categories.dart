import '../../domain/models/category_group.dart';

class DefaultCategoryGroupSeed {
  const DefaultCategoryGroupSeed({
    required this.name,
    required this.type,
    required this.systemKey,
    required this.sortOrder,
    required this.categories,
  });

  final String name;
  final CategoryType type;
  final String systemKey;
  final int sortOrder;
  final List<DefaultCategorySeed> categories;
}

class DefaultCategorySeed {
  const DefaultCategorySeed({
    required this.name,
    required this.systemKey,
    required this.sortOrder,
  });

  final String name;
  final String systemKey;
  final int sortOrder;
}

const defaultCategoryGroups = <DefaultCategoryGroupSeed>[
  DefaultCategoryGroupSeed(
    name: 'Housing',
    type: CategoryType.expense,
    systemKey: 'housing',
    sortOrder: 0,
    categories: [
      DefaultCategorySeed(
        name: 'Rent / Mortgage',
        systemKey: 'housing.rent',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Utilities',
        systemKey: 'housing.utilities',
        sortOrder: 1,
      ),
      DefaultCategorySeed(
        name: 'Home Maintenance',
        systemKey: 'housing.maintenance',
        sortOrder: 2,
      ),
      DefaultCategorySeed(
        name: 'Groceries',
        systemKey: 'food.groceries',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Eating Out',
        systemKey: 'food.eating_out',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Transport',
    type: CategoryType.expense,
    systemKey: 'transport',
    sortOrder: 2,
    categories: [
      DefaultCategorySeed(
        name: 'Fuel',
        systemKey: 'transport.fuel',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Public Transport',
        systemKey: 'transport.public_transport',
        sortOrder: 1,
      ),
      DefaultCategorySeed(
        name: 'Vehicle Maintenance',
        systemKey: 'transport.maintenance',
        sortOrder: 2,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Personal',
    type: CategoryType.expense,
    systemKey: 'personal',
    sortOrder: 3,
    categories: [
      DefaultCategorySeed(
        name: 'Clothing',
        systemKey: 'personal.clothing',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Personal Care',
        systemKey: 'personal.care',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Health',
    type: CategoryType.expense,
    systemKey: 'health',
    sortOrder: 4,
    categories: [
      DefaultCategorySeed(
        name: 'Medical',
        systemKey: 'health.medical',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Fitness',
        systemKey: 'health.fitness',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Family',
    type: CategoryType.expense,
    systemKey: 'family',
    sortOrder: 5,
    categories: [
      DefaultCategorySeed(
        name: 'Children',
        systemKey: 'family.children',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Family Support',
        systemKey: 'family.support',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Financial',
    type: CategoryType.expense,
    systemKey: 'financial',
    sortOrder: 6,
    categories: [
      DefaultCategorySeed(
        name: 'Bank Fees',
        systemKey: 'financial.bank_fees',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Mobile Money Fees',
        systemKey: 'financial.mobile_money_fees',
        sortOrder: 1,
      ),
      DefaultCategorySeed(
        name: 'Debt Payments',
        systemKey: 'financial.debt_payments',
        sortOrder: 2,
      ),
      DefaultCategorySeed(
        name: 'Fees & Charges',
        systemKey: 'expense.fees_charges',
        sortOrder: 4,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Lifestyle',
    type: CategoryType.expense,
    systemKey: 'lifestyle',
    sortOrder: 7,
    categories: [
      DefaultCategorySeed(
        name: 'Entertainment',
        systemKey: 'lifestyle.entertainment',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Subscriptions',
        systemKey: 'lifestyle.subscriptions',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Giving',
    type: CategoryType.expense,
    systemKey: 'giving',
    sortOrder: 8,
    categories: [
      DefaultCategorySeed(
        name: 'Gifts',
        systemKey: 'giving.gifts',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Donations',
        systemKey: 'giving.donations',
        sortOrder: 1,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Other',
    type: CategoryType.expense,
    systemKey: 'other_expense',
    sortOrder: 9,
    categories: [
      DefaultCategorySeed(
        name: 'Miscellaneous',
        systemKey: 'other_expense.miscellaneous',
        sortOrder: 0,
      ),
    ],
  ),
  DefaultCategoryGroupSeed(
    name: 'Income',
    type: CategoryType.income,
    systemKey: 'income',
    sortOrder: 0,
    categories: [
      DefaultCategorySeed(
        name: 'Salary',
        systemKey: 'income.salary',
        sortOrder: 0,
      ),
      DefaultCategorySeed(
        name: 'Business Income',
        systemKey: 'income.business',
        sortOrder: 1,
      ),
      DefaultCategorySeed(
        name: 'Freelance',
        systemKey: 'income.freelance',
        sortOrder: 2,
      ),
      DefaultCategorySeed(
        name: 'Interest',
        systemKey: 'income.interest',
        sortOrder: 3,
      ),
      DefaultCategorySeed(
        name: 'Gifts Received',
        systemKey: 'income.gifts',
        sortOrder: 4,
      ),
      DefaultCategorySeed(
        name: 'Other Income',
        systemKey: 'income.other',
        sortOrder: 5,
      ),
      DefaultCategorySeed(
        name: 'Fees & Charges',
        systemKey: 'income.fees_charges',
        sortOrder: 6,
      ),
    ],
  ),
];