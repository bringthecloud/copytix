
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchLogs({
    int limit = 300,
  }) async {
    final response = await _client
        .from('log_aktivitas')
        .select(
          'id_log,'
          'waktu,'
          'aksi,'
          'nama_tabel,'
          'id_data,'
          'detail,'
          'pengguna:pengguna!log_aktivitas_id_pengguna_fkey('
          'nama,email,role'
          ')',
        )
        .order('waktu', ascending: false)
        .limit(limit);

    return response
        .map<Map<String, dynamic>>(
          (row) => Map<String, dynamic>.from(row as Map),
        )
        .toList();
  }
}
