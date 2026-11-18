import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../dashboard/dashboard_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final repository = AuthRepository(client);

    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? repository.currentSession;
        if (session == null) {
          return const LoginPage();
        }

        return _ProfileGate(
          key: ValueKey(session.user.id),
          repository: repository,
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({required this.repository, super.key});

  final AuthRepository repository;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.repository.getCurrentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _AccessErrorPage(
            message: 'Profil pengguna tidak dapat dimuat. ${snapshot.error}',
            onSignOut: widget.repository.signOut,
          );
        }

        final profile = snapshot.data!;
        final isActive = profile['aktif'] == true;
        final role = profile['role'] as String?;
        if (!isActive || (role != 'admin_pemilik' && role != 'kasir')) {
          return _AccessErrorPage(
            message: 'Akun tidak aktif atau role belum diatur oleh Admin/Pemilik.',
            onSignOut: widget.repository.signOut,
          );
        }

        return DashboardPage(
          userName: profile['nama'] as String? ?? 'Pengguna Copytix',
          role: role,
          onSignOut: widget.repository.signOut,
        );
      },
    );
  }
}

class _AccessErrorPage extends StatelessWidget {
  const _AccessErrorPage({required this.message, required this.onSignOut});

  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async => onSignOut(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
