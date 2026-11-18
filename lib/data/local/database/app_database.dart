import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../tables/sync_queue.dart';
import '../tables/products.dart';
import '../tables/service_types.dart';
import '../tables/customers.dart';
import '../tables/sales.dart';
import '../tables/sale_items.dart';
import '../tables/inventory_movements.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SyncQueue,
    Products,
    ServiceTypes,
    Customers,
    Sales,
    SaleItems,
    InventoryMovements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'copytix_local'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(products);
        await m.createTable(serviceTypes);
        await m.createTable(customers);
      }

      if (from < 3) {
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.createTable(inventoryMovements);
      }
    },
  );
}
