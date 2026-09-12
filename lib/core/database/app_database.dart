import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

//
// ACCOUNTS
//

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get provider => text().nullable()();

  IntColumn get openingBalance =>
      integer().withDefault(const Constant(0))();

  IntColumn get currentBalance =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// CATEGORY GROUPS
//

class CategoryGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get systemKey => text().nullable()();

  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// CATEGORIES
//

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get groupId => integer().references(
    CategoryGroups,
    #id,
  )();

  TextColumn get name => text()();

  TextColumn get systemKey => text().nullable()();

  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// TRANSACTIONS
//

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// income | expense | transfer
  TextColumn get type => text()();

  /// Income:
  ///   Receiving account.
  ///
  /// Expense:
  ///   Spending account.
  ///
  /// Transfer:
  ///   Source account.
  IntColumn get accountId => integer().references(
    Accounts,
    #id,
  )();

  /// Only populated for transfers.
  IntColumn get destinationAccountId => integer()
      .nullable()
      .references(
    Accounts,
    #id,
  )();

  /// Nullable because uncategorized Income/Expense transactions
  /// are allowed.
  ///
  /// Transfers must leave this null.
  ///
  /// For itemized Expense transactions, line-item categories
  /// become authoritative for budget spending.
  IntColumn get categoryId => integer()
      .nullable()
      .references(
    Categories,
    #id,
  )();

  /// Principal transaction amount in ngwee.
  ///
  /// Stored as a positive integer.
  IntColumn get amount => integer()();

  /// Additional financial cost in ngwee.
  ///
  /// Kept separate from the principal amount.
  IntColumn get fee =>
      integer().withDefault(const Constant(0))();

  TextColumn get payee => text().nullable()();

  TextColumn get note => text().nullable()();

  /// Actual date/time of the financial event.
  DateTimeColumn get occurredAt => dateTime()();

  /// manual | sms
  TextColumn get source =>
      text().withDefault(const Constant('manual'))();

  /// External provider/bank transaction identifier.
  ///
  /// Intentionally not globally unique because different
  /// providers may have overlapping identifier namespaces.
  TextColumn get externalTransactionId => text().nullable()();

  /// Ledger transactions are soft-deleted.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// BUDGET SETTINGS
//

/// Establishes the point at which Nomi's budgeting system begins.
///
/// The service layer will treat this table as a singleton.
///
/// [budgetStartDate] is intentionally a full DateTime rather than just
/// a month. This prevents transactions that occurred earlier in the
/// first budget month from being counted twice when those transactions
/// are already reflected in the account-balance snapshot.
///
/// [initialAssignableAmount] is the amount of money owned at the moment
/// budgeting is initialized.
///
/// It is stored in ngwee.
class BudgetSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get budgetStartDate => dateTime()();

  IntColumn get initialAssignableAmount => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// BUDGET MONTHS
//

/// Stable monthly container for budget decisions.
///
/// Calculated values such as:
///
/// - income
/// - spent
/// - available
/// - rollover
/// - left to assign
///
/// are deliberately NOT stored here.
///
/// Those values will be derived by BudgetService from the authoritative
/// ledger and allocations.
class BudgetMonths extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get year => integer()();

  IntColumn get month => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {
      year,
      month,
    },
  ];
}

//
// BUDGET ALLOCATIONS
//

/// Records how much money was deliberately assigned to an Expense
/// category for a particular month.
///
/// This does not move money between Accounts and does not create a
/// financial transaction.
///
/// [assignedAmount] is stored in ngwee.
///
/// It may be:
///
/// positive:
///   money assigned to the category
///
/// zero:
///   nothing assigned
///
/// negative:
///   money removed from the category during the month
///
/// The service/UI will normally store the final NET assignment for
/// the category/month.
class BudgetAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get budgetMonthId => integer().references(
    BudgetMonths,
    #id,
  )();

  IntColumn get categoryId => integer().references(
    Categories,
    #id,
  )();

  IntColumn get assignedAmount => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {
      budgetMonthId,
      categoryId,
    },
  ];
}

//
// ITEM DEFINITIONS
//

/// Reusable catalog identity for a commodity, product, service,
/// recurring cost, or other budgetable item.
///
/// Examples:
///
/// - Sugar
/// - Cooking Oil
/// - Bathing Soap
/// - Electricity
/// - Internet
/// - Bus Fare
/// - Haircut
///
/// An ItemDefinition is NOT itself a budget allocation.
///
/// [defaultCategoryId] is only a convenience used when planning.
/// Historical monthly plans retain their own category.
///
/// [defaultUnit] is also only a default. Historical plans and
/// transaction line items snapshot their actual units.
///
/// Items are soft-deactivated so historical purchase data remains
/// meaningful.
class ItemDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get defaultCategoryId => integer()
      .nullable()
      .references(
    Categories,
    #id,
  )();

  TextColumn get defaultUnit => text().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// MONTHLY PLANNED ITEMS
//

/// Item-level plan inside a monthly category budget.
///
/// Example:
///
/// September
///   Groceries
///     Sugar
///       planned quantity: 2 kg
///       planned amount: K120
///
/// A planned item does NOT allocate additional money.
///
/// The parent category's BudgetAllocation remains the financial
/// envelope.
///
/// Null values are meaningful:
///
/// plannedAmount == null
///   means price/cost is not currently known.
///
/// plannedQuantity == null
///   means quantity is not specified.
///
/// Never use zero as a replacement for "unknown".
///
/// Quantity uses a fixed scale of 1,000.
///
/// Examples:
///
/// 1     unit = 1000
/// 1.5   units = 1500
/// 0.25  units = 250
///
/// This avoids binary floating-point quantities.
class MonthlyPlannedItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get budgetMonthId => integer().references(
    BudgetMonths,
    #id,
  )();

  IntColumn get categoryId => integer().references(
    Categories,
    #id,
  )();

  /// Optional because users may create an ad-hoc monthly item
  /// without first adding it to the reusable catalog.
  IntColumn get itemDefinitionId => integer()
      .nullable()
      .references(
    ItemDefinitions,
    #id,
  )();

  /// Snapshot retained for historical stability.
  TextColumn get nameSnapshot => text()();

  /// Fixed-scale quantity:
  ///
  /// stored value / 1000 = user-facing quantity.
  IntColumn get plannedQuantity => integer().nullable()();

  /// Snapshot of the unit used for this plan.
  ///
  /// Examples:
  /// kg, g, litre, ml, piece, pack, month, trip.
  TextColumn get unitSnapshot => text().nullable()();

  /// Planned total amount in ngwee.
  ///
  /// Null means currently unknown.
  IntColumn get plannedAmount => integer().nullable()();

  /// Allows an item without measurable quantity/price to still be
  /// manually marked as completed.
  ///
  /// Actual linked purchases can later contribute to derived
  /// fulfillment information independently of this flag.
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// TRANSACTION LINE ITEMS
//

/// Detailed contents of an Expense transaction.
///
/// The parent FinanceTransaction remains the authoritative payment
/// event and account movement.
///
/// Example:
///
/// Transaction:
///   Shoprite
///   amount = K450
///
/// Line items:
///   Sugar       Groceries   K120
///   Oil         Groceries   K180
///   Soap        Household    K70
///   Toothpaste  Household    K80
///
/// For fully itemized expenses:
///
///   SUM(line item amount) == transaction.amount
///
/// Transaction fees remain separate and are NOT included in the
/// line-item sum.
///
/// When an Expense has no line items, Transactions.categoryId remains
/// authoritative for category spending.
///
/// When an Expense has line items, these line-item category IDs become
/// authoritative for category spending.
///
/// This table deliberately has no isDeleted flag. Its parent transaction
/// already uses soft deletion. Budget/report queries will ignore line
/// items whose parent transaction is deleted.
class TransactionLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get transactionId => integer().references(
    Transactions,
    #id,
  )();

  IntColumn get categoryId => integer().references(
    Categories,
    #id,
  )();

  IntColumn get itemDefinitionId => integer()
      .nullable()
      .references(
    ItemDefinitions,
    #id,
  )();

  /// Optional link back to the monthly plan this purchase fulfills.
  ///
  /// Multiple transaction line items may reference the same planned
  /// item, allowing partial purchases.
  IntColumn get monthlyPlannedItemId => integer()
      .nullable()
      .references(
    MonthlyPlannedItems,
    #id,
  )();

  /// Historical snapshot of what was actually purchased.
  TextColumn get nameSnapshot => text()();

  /// Fixed-scale quantity:
  ///
  /// stored value / 1000 = user-facing quantity.
  IntColumn get quantity => integer().nullable()();

  /// Historical unit snapshot.
  TextColumn get unitSnapshot => text().nullable()();

  /// Actual amount paid for this line item in ngwee.
  ///
  /// Transaction fees are excluded.
  IntColumn get amount => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

//
// DATABASE
//

@DriftDatabase(
  tables: [
    Accounts,
    CategoryGroups,
    Categories,
    Transactions,
    BudgetSettings,
    BudgetMonths,
    BudgetAllocations,
    ItemDefinitions,
    MonthlyPlannedItems,
    TransactionLineItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      //
      // Schema 2
      //
      if (from < 2) {
        await migrator.createTable(categoryGroups);
        await migrator.createTable(categories);
      }

      //
      // Schema 3
      //
      if (from < 3) {
        await migrator.createTable(transactions);
      }

      //
      // Schema 4
      //
      // Budget Engine + item-level planning + transaction
      // line-item infrastructure.
      //
      if (from < 4) {
        await migrator.createTable(budgetSettings);
        await migrator.createTable(budgetMonths);
        await migrator.createTable(budgetAllocations);
        await migrator.createTable(itemDefinitions);
        await migrator.createTable(monthlyPlannedItems);
        await migrator.createTable(transactionLineItems);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'kopa',
  );
}
