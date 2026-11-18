import 'package:drift/drift.dart';

import 'products.dart';

class InventoryMovements extends Table {
  // Unique movement ID
  TextColumn get id => text()();

  // Product reference
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  // purchase, sale, adjustment, return
  TextColumn get movementType => text()();

  // Quantity is always stored as a positive number.
  RealColumn get quantity => real()();

  // Stock before and after movement
  RealColumn get stockBefore => real()();
  RealColumn get stockAfter => real()();

  // Reference to related transaction
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
