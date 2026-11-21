import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final response = await _client
        .from('barang')
        .select('id_barang, nama_barang, satuan, stok, stok_minimum')
        .order('nama_barang');

    return response.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> saveItem({
    String? id,
    required String nama,
    required String satuan,
    required int stokMinimum,
  }) async {
    final data = {
      'nama_barang': nama.trim(),
      'satuan': satuan.trim(),
      'stok_minimum': stokMinimum,
    };

    if (id == null) {
      await _client.from('barang').insert(data);
    } else {
      await _client.from('barang').update(data).eq('id_barang', id);
    }
  }

  Future<void> recordMovement({
    required String idBarang,
    required String jenis,
    required int jumlah,
    required String keterangan,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw AuthException('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    if (jenis != 'masuk' && jenis != 'penyesuaian') {
      throw ArgumentError('Jenis mutasi stok tidak valid.');
    }

    if (jumlah == 0 || (jenis == 'masuk' && jumlah < 0)) {
      throw ArgumentError('Jumlah stok tidak valid.');
    }

    await _client.from('mutasi_stok').insert({
      'id_barang': idBarang,
      'id_pengguna': user.id,
      'id_transaksi': null,
      'id_detail': null,
      'jenis': jenis,
      'jumlah': jumlah,
      'keterangan': keterangan.trim().isEmpty ? null : keterangan.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchRecentMovements({
    int limit = 10,
  }) async {
    final response = await _client
        .from('mutasi_stok')
        .select(
          'id_mutasi, id_barang, jenis, jumlah, '
          'tanggal_mutasi, keterangan',
        )
        .order('tanggal_mutasi', ascending: false)
        .limit(limit);

    return response.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
