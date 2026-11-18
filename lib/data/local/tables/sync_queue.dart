import 'package:drift/drift.dart';

class SyncQueue extends Table {
  // UUID unik untuk setiap pekerjaan sinkronisasi.
  TextColumn get id => text()();

  // Contoh: product, customer, sale.
  TextColumn get entityType => text()();

  // ID data yang akan disinkronkan.
  TextColumn get entityId => text()();

  // Contoh: insert, update, delete.
  TextColumn get operation => text()();

  // Data dalam format JSON.
  TextColumn get payload => text()();

  // Status antrean.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  // Jumlah percobaan sinkronisasi.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  // Waktu pembuatan antrean.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Jadwal percobaan selanjutnya.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  // Pesan error terakhir, jika ada.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
