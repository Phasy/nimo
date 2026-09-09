import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

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

@DriftDatabase(
  tables: [
    Accounts,
    CategoryGroups,
    Categories,
    Transactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(categoryGroups);
        await migrator.createTable(categories);
      }

      if (from < 3) {
        await migrator.createTable(transactions);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'kopa',
  );
}