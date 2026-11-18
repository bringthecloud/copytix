class SupabaseConfig {
  SupabaseConfig._();

  // Provide these at run/build time with --dart-define.
  // Only the Supabase project URL and publishable client key belong in Flutter.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Supabase belum dikonfigurasi. Jalankan aplikasi dengan '
        '--dart-define=SUPABASE_URL=... dan '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL bukan URL yang valid.');
    }
  }
}
