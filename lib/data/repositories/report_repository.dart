
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  static const int _pageSize = 500;

  /// Fetches transactions within a date range.
  /// The end date is exclusive.
  ///
  /// RLS controls which transactions the signed-in user can access.
  Future<List<Map<String, dynamic>>> fetchTransactions({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    if (!endExclusive.isAfter(startInclusive)) {
      throw ArgumentError(
        'The report end date must be after the start date.',
      );
    }

    final startUtc = startInclusive.toUtc().toIso8601String();
    final endUtc = endExclusive.toUtc().toIso8601String();

    final transactions = <Map<String, dynamic>>[];

    var offset = 0;

    while (true) {
      final response = await _client
          .from('transaksi')
          .select('''
            id_transaksi,
            kode_transaksi,
            tanggal_transaksi,
            total,
            status_pesanan,
            pembayaran (
              metode,
              nominal
            )
          ''')
          .gte('tanggal_transaksi', startUtc)
          .lt('tanggal_transaksi', endUtc)
          .order('tanggal_transaksi', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final page = response
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      transactions.addAll(page);

      if (page.length < _pageSize) {
        break;
      }

      offset += _pageSize;
    }

    return transactions;
  }
}
