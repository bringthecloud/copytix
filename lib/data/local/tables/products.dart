import 'package:drift/drift.dart';

class Products extends Table {
  // Unique product ID (UUID)
  TextColumn get id => text()();

  // Product information
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get sku => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  // Pricing (Indonesian Rupiah)
  IntColumn get costPrice => integer().withDefault(const Constant(0))();

  IntColumn get sellingPrice => integer()();

  // Inventory
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();

  RealColumn get minimumStock => real().withDefault(const Constant(0.0))();

  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
