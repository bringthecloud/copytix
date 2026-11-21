
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRepository {
  ServiceRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final response = await _client
        .from('layanan')
        .select('id_layanan, nama_layanan, satuan, harga, aktif')
        .order('nama_layanan');

    return response
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> save({
    String? id,
    required String nama,
    required String satuan,
    required double harga,
    required bool aktif,
  }) async {
    final data = {
      'nama_layanan': nama.trim(),
      'satuan': satuan.trim(),
      'harga': harga,
      'aktif': aktif,
    };

    if (id == null) {
      await _client.from('layanan').insert(data);
    } else {
      await _client
          .from('layanan')
          .update(data)
          .eq('id_layanan', id);
    }
  }

  Future<void> setActive({
    required String id,
    required bool aktif,
  }) async {
    await _client
        .from('layanan')
        .update({'aktif': aktif})
        .eq('id_layanan', id);
  }

  Future<List<Map<String, dynamic>>> fetchInventoryItems() async {
    final response = await _client
        .from('barang')
        .select('id_barang, nama_barang, satuan, stok')
        .order('nama_barang');

    return response
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMaterials(
    String serviceId,
  ) async {
    final mappings = await _client
        .from('layanan_barang')
        .select('id_barang, jumlah_per_layanan')
        .eq('id_layanan', serviceId);

    if (mappings.isEmpty) {
      return [];
    }

    final items = await fetchInventoryItems();

    final itemsById = {
      for (final item in items)
        item['id_barang'] as String: item,
    };

    return mappings.map((mapping) {
      final itemId = mapping['id_barang'] as String;
      final item = itemsById[itemId];

      return {
        'id_barang': itemId,
        'jumlah_per_layanan':
            mapping['jumlah_per_layanan'],
        'nama_barang':
            item?['nama_barang'] ?? 'Barang tidak ditemukan',
        'satuan': item?['satuan'] ?? '-',
        'stok': item?['stok'] ?? 0,
      };
    }).toList();
  }

  Future<void> saveMaterial({
    required String serviceId,
    required String itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Jumlah pemakaian harus lebih dari 0.',
      );
    }

    await _client.from('layanan_barang').upsert(
      {
        'id_layanan': serviceId,
        'id_barang': itemId,
        'jumlah_per_layanan': quantity,
      },
      onConflict: 'id_layanan,id_barang',
    );
  }

  Future<void> removeMaterial({
    required String serviceId,
    required String itemId,
  }) async {
    await _client
        .from('layanan_barang')
        .delete()
        .eq('id_layanan', serviceId)
        .eq('id_barang', itemId);
  }
}
