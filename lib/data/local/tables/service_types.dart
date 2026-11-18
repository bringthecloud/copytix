import 'package:drift/drift.dart';

class ServiceTypes extends Table {
  // Unique service ID (UUID)
  TextColumn get id => text()();

  // Service information
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().nullable()();

  // Examples: lembar, halaman, set, pcs
  TextColumn get unit => text().withDefault(const Constant('lembar'))();

  // Service price in Rupiah
  IntColumn get price => integer()();

  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
