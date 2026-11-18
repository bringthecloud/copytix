import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    final profile = await _client
        .from('pengguna')
        .select('id_pengguna, email, nama, role, aktif')
        .eq('id_pengguna', user.id)
        .single();

    return profile;
  }
}
