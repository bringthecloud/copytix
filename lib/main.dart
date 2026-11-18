import 'package:flutter/material.dart';

import 'app/copytix_app.dart';
import 'data/local/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Membuka database lokal dan memverifikasi koneksi SQLite.
  try {
    await DatabaseProvider.instance.customSelect('SELECT 1').getSingle();

    debugPrint('Copytix SQLite database connected successfully.');
  } catch (error, stackTrace) {
    debugPrint('Failed to initialize Copytix database: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  runApp(const CopytixApp());
}
