
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  static const String _transactionSelect = '''
    id_transaksi,
    kode_transaksi,
    tanggal_transaksi,
    total,
    status_pesanan,
    catatan,
    id_pengguna,
    detail_transaksi (
      id_detail,
      id_layanan,
      jumlah,
      harga_satuan,
      subtotal,
      layanan (
        nama_layanan,
        satuan
      )
    ),
    pembayaran (
      id_pembayaran,
      tanggal_pembayaran,
      metode,
      nominal,
      uang_diterima,
      kembalian
    )
  ''';

  /// Mengambil riwayat transaksi.
  /// RLS Supabase membatasi data sesuai role pengguna.
  Future<List<Map<String, dynamic>>> fetchHistory({
    int limit = 100,
  }) async {
    if (limit <= 0) {
      throw ArgumentError('Limit harus lebih dari 0.');
    }

    final response = await _client
        .from('transaksi')
        .select(_transactionSelect)
        .order('tanggal_transaksi', ascending: false)
        .limit(limit);

    return response
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Mengambil satu transaksi beserta detail dan pembayarannya.
  Future<Map<String, dynamic>> fetchById(
    String transactionId,
  ) async {
    final response = await _client
        .from('transaksi')
        .select(_transactionSelect)
        .eq('id_transaksi', transactionId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// Menyimpan checkout melalui fungsi PostgreSQL.
  ///
  /// Proses transaksi, detail, pembayaran, dan pengurangan
  /// stok ditangani oleh fungsi simpan_transaksi di Supabase.
  Future<Map<String, dynamic>> checkout({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    double? amountReceived,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Transaksi belum memiliki layanan.');
    }

    if (paymentMethod != 'tunai' &&
        paymentMethod != 'non_tunai') {
      throw ArgumentError('Metode pembayaran tidak valid.');
    }

    if (paymentMethod == 'tunai' &&
        (amountReceived == null || amountReceived <= 0)) {
      throw ArgumentError(
        'Jumlah uang yang diterima harus lebih dari 0.',
      );
    }

    final normalizedItems = items.map((item) {
      final serviceId = item['id_layanan'];
      final quantity = item['jumlah'];

      if (serviceId is! String || serviceId.isEmpty) {
        throw ArgumentError('ID layanan tidak valid.');
      }

      if (quantity is! int || quantity <= 0) {
        throw ArgumentError(
          'Jumlah layanan harus berupa bilangan bulat lebih dari 0.',
        );
      }

      return {
        'id_layanan': serviceId,
        'jumlah': quantity,
      };
    }).toList();

    final response = await _client.rpc(
      'simpan_transaksi',
      params: {
        'p_items': normalizedItems,
        'p_metode': paymentMethod,
        'p_uang_diterima': amountReceived,
        'p_catatan': notes?.trim().isEmpty == true
            ? null
            : notes?.trim(),
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Respons checkout dari server tidak valid.',
      );
    }

    return Map<String, dynamic>.from(response);
  }

  /// Mengubah status pesanan melalui fungsi PostgreSQL.
  Future<void> updateStatus({
    required String transactionId,
    required String status,
  }) async {
    const validStatuses = {
      'diproses',
      'selesai',
      'diambil',
      'dibatalkan',
    };

    if (!validStatuses.contains(status)) {
      throw ArgumentError('Status pesanan tidak valid.');
    }

    await _client.rpc(
      'ubah_status_pesanan',
      params: {
        'p_id_transaksi': transactionId,
        'p_status': status,
      },
    );
  }
}
