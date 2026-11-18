import 'package:drift/drift.dart';

import 'customers.dart';

class Sales extends Table {
  // Unique transaction ID (UUID)
  TextColumn get id => text()();

  // Unique receipt number
  TextColumn get receiptNumber => text().unique()();

  // Optional customer
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Transaction totals in Rupiah
  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  IntColumn get discountAmount => integer().withDefault(const Constant(0))();

  IntColumn get total => integer().withDefault(const Constant(0))();

  IntColumn get amountPaid => integer().withDefault(const Constant(0))();

  IntColumn get changeAmount => integer().withDefault(const Constant(0))();

  // cash, transfer, qris, etc.
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();

  // completed, cancelled, etc.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  TextColumn get notes => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
