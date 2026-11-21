
import 'package:flutter/material.dart';

import '../activity/activity_log_page.dart';
import '../cashier/cashier_page.dart';
import '../cashier/transaction_history_page.dart';
import '../inventory/inventory_page.dart';
import '../reports/reports_page.dart';
import '../services/services_page.dart';

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
    final isAdmin = role == 'admin_pemilik';

    final roleLabel = isAdmin ? 'Admin / Owner' : 'Cashier';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copytix'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await onSignOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hello, $userName',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            roleLabel,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard_rounded,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account connected successfully'),
                        SizedBox(height: 4),
                        Text(
                          'Manage Studio & Fotocopy Andry operations with Copytix.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.point_of_sale_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Transactions'),
              subtitle: const Text(
                'Create transactions and process payments',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CashierPage(),
                  ),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Transaction History'),
              subtitle: const Text(
                'View transaction details and manage order status',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryPage(),
                  ),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.design_services_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Services'),
              subtitle: const Text(
                'View and manage service catalog',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServicesPage(
                      isAdmin: isAdmin,
                    ),
                  ),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.inventory_2_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Inventory'),
              subtitle: const Text(
                'View inventory and manage stock movements',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InventoryPage(
                      isAdmin: isAdmin,
                    ),
                  ),
                );
              },
            ),
          ),

          if (isAdmin) ...[
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.bar_chart_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Reports'),
                subtitle: const Text(
                  'View daily and monthly sales reports',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReportsPage(),
                    ),
                  );
                },
              ),
            ),

            Card(
              child: ListTile(
                leading: Icon(
                  Icons.history_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Activity Log'),
                subtitle: const Text(
                  'View user activity and system records',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ActivityLogPage(),
                    ),
                  );
                },
              ),
            ),

            const _ComingSoonTile(
              icon: Icons.people_outline,
              title: 'Users',
            ),
          ],
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        trailing: const Text('Coming soon'),
      ),
    );
  }
}
