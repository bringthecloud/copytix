import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.userName,
    required this.role,
    required this.onSignOut,
    super.key,
  });

  final String userName;
  final String role;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = role == 'admin_pemilik' ? 'Admin / Pemilik' : 'Kasir';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copytix'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async => onSignOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Halo, $userName', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(roleLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.dashboard_rounded, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fondasi akun berhasil terhubung'),
                        SizedBox(height: 4),
                        Text('Halaman dashboard dan modul operasional akan dibangun pada tahap berikutnya.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ComingSoonTile(icon: Icons.design_services_outlined, title: 'Layanan'),
          const _ComingSoonTile(icon: Icons.inventory_2_outlined, title: 'Barang dan Stok'),
          const _ComingSoonTile(icon: Icons.point_of_sale_outlined, title: 'Transaksi'),
          if (role == 'admin_pemilik') ...[
            const _ComingSoonTile(icon: Icons.people_outline, title: 'Pengguna'),
            const _ComingSoonTile(icon: Icons.bar_chart_outlined, title: 'Laporan'),
          ],
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Text('Segera'),
      ),
    );
  }
}
