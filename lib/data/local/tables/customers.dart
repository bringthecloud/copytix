import 'package:drift/drift.dart';

class Customers extends Table {
  // Unique customer ID (UUID)
  TextColumn get id => text()();

  // Customer information
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
