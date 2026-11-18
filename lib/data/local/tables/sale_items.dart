import 'package:drift/drift.dart';

import 'sales.dart';
import 'products.dart';
import 'service_types.dart';

class SaleItems extends Table {
  // Unique item ID
  TextColumn get id => text()();

  // Parent transaction
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();

  // product or service
  TextColumn get itemType => text()();

  // Reference to product or service
  // One of these can be null depending on itemType.
  TextColumn get productId => text().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get serviceTypeId => text().nullable().references(
    ServiceTypes,
    #id,
    onDelete: KeyAction.setNull,
  )();

  // Snapshot information
  TextColumn get itemName => text()();
  TextColumn get unit => text()();

  // Price and quantity
  IntColumn get unitPrice => integer()();
  RealColumn get quantity => real()();
  IntColumn get lineTotal => integer()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
