
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/activity_repository.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late final ActivityRepository _repository;

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _logs = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _repository = ActivityRepository(
      Supabase.instance.client,
    );

    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _repository.fetchLogs();

      if (!mounted) return;

      setState(() {
        _logs = result;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to load activity log: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is List &&
        value.isNotEmpty &&
        value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }

    return null;
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) return '-';

    final date = parsed.toLocal();

    return '${_twoDigits(date.day)}/'
        '${_twoDigits(date.month)}/'
        '${date.year} '
        '${_twoDigits(date.hour)}:'
        '${_twoDigits(date.minute)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(dynamic value) {
    final amount = _toDouble(value).round();

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'diproses':
        return 'Processing';
      case 'selesai':
        return 'Completed';
      case 'diambil':
        return 'Collected';
      case 'dibatalkan':
        return 'Cancelled';
      default:
        return value?.toString() ?? '-';
    }
  }

  String _paymentMethodLabel(dynamic value) {
    switch (value?.toString()) {
      case 'tunai':
        return 'Cash';
      case 'non_tunai':
        return 'Non-cash';
      default:
        return value?.toString() ?? '-';
    }
  }

  // Converts database action names into readable activity labels.
  String _actionLabel(String action) {
    switch (action) {
      case 'simpan_transaksi':
        return 'Transaction Created';

      case 'ubah_status_pesanan':
        return 'Order Status Updated';

      case 'mutasi_stok':
        return 'Stock Movement Recorded';
    }

    String? verb;
    String target;

    if (action.startsWith('buat_')) {
      verb = 'Created';
      target = action.substring(5);
    } else if (action.startsWith('ubah_')) {
      verb = 'Updated';
      target = action.substring(5);
    } else if (action.startsWith('hapus_')) {
      verb = 'Deleted';
      target = action.substring(6);
    } else {
      return action.replaceAll('_', ' ');
    }

    String subject;

    switch (target) {
      case 'layanan':
        subject = 'Service';
        break;

      case 'barang':
        subject = 'Inventory Item';
        break;

      case 'layanan_barang':
        subject = 'Service Materials';
        break;

      case 'pengguna':
        subject = 'User';
        break;

      default:
        subject = target.replaceAll('_', ' ');
    }

    return '$subject $verb';
  }

  // Selects an icon based on the activity type.
  IconData _actionIcon(String action) {
    switch (action) {
      case 'simpan_transaksi':
        return Icons.point_of_sale_outlined;

      case 'ubah_status_pesanan':
        return Icons.sync_alt_rounded;

      case 'mutasi_stok':
        return Icons.inventory_2_outlined;
    }

    if (action.startsWith('buat_')) {
      return Icons.add_circle_outline;
    }

    if (action.startsWith('ubah_')) {
      return Icons.edit_outlined;
    }

    if (action.startsWith('hapus_')) {
      return Icons.delete_outline;
    }

    return Icons.history_rounded;
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'simpan_transaksi':
        return Colors.teal;

      case 'ubah_status_pesanan':
        return Colors.indigo;

      case 'mutasi_stok':
        return Colors.green;

      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // Converts database table names into readable labels.
  String _tableLabel(dynamic value) {
    switch (value?.toString()) {
      case 'transaksi':
        return 'Transaction';

      case 'barang':
        return 'Inventory';

      case 'layanan':
        return 'Service';

      case 'layanan_barang':
        return 'Service Materials';

      case 'pengguna':
        return 'User';

      case 'pembayaran':
        return 'Payment';

      case 'mutasi_stok':
        return 'Stock Movement';

      default:
        return value?.toString() ?? 'General';
    }
  }

  // Creates a readable description from the activity JSON data.
  String _detailDescription(
    String action,
    dynamic rawDetail,
  ) {
    final detail = _asMap(rawDetail);

    if (detail == null || detail.isEmpty) {
      return 'No additional details';
    }

    // Stock movement activity.
    if (action == 'mutasi_stok') {
      final item =
          (detail['barang'] ?? 'Inventory item').toString();

      final quantity =
          (detail['jumlah'] ?? '-').toString();

      final stockType =
          (detail['jenis'] ?? '').toString();

      String movement;

      switch (stockType) {
        case 'masuk':
          movement = 'Stock In';
          break;

        case 'keluar':
          movement = 'Stock Out';
          break;

        case 'pembatalan':
          movement = 'Stock Restored';
          break;

        case 'penyesuaian':
          movement = 'Stock Adjustment';
          break;

        default:
          movement = 'Stock Movement';
      }

      final parts = <String>[
        item,
        '$movement: $quantity',
      ];

      final transactionCode =
          detail['kode_transaksi']?.toString();

      if (transactionCode != null &&
          transactionCode.isNotEmpty) {
        parts.add(transactionCode);
      }

      return parts.join(' • ');
    }

    final code = detail['kode']?.toString();

    // Transaction creation activity.
    if (action == 'simpan_transaksi') {
      final parts = <String>[];

      if (code != null && code.isNotEmpty) {
        parts.add(code);
      }

      if (detail['total'] != null) {
        parts.add(
          _formatCurrency(detail['total']),
        );
      }

      if (detail['metode'] != null) {
        parts.add(
          _paymentMethodLabel(detail['metode']),
        );
      }

      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
    }

    // Order status update activity.
    if (action == 'ubah_status_pesanan') {
      final from = _statusLabel(detail['dari']);
      final to = _statusLabel(detail['ke']);

      if (code != null && code.isNotEmpty) {
        return '$code • $from → $to';
      }

      return '$from → $to';
    }

    // General activity details.
    final parts = <String>[];

    for (final entry in detail.entries) {
      if (entry.value == null) continue;

      final key = entry.key.replaceAll('_', ' ');

      parts.add('$key: ${entry.value}');

      if (parts.length >= 3) break;
    }

    return parts.isEmpty
        ? 'No additional details'
        : parts.join(' • ');
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final keyword =
        _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) return _logs;

    return _logs.where((log) {
      final user = _asMap(log['pengguna']);

      final actor =
          (user?['nama'] ?? user?['email'] ?? 'System')
              .toString();

      final action =
          (log['aksi'] ?? '').toString();

      final table =
          (log['nama_tabel'] ?? '').toString();

      final detail = _detailDescription(
        action,
        log['detail'],
      );

      final searchable =
          '$actor $action $table $detail'.toLowerCase();

      return searchable.contains(keyword);
    }).toList();
  }

  Widget _buildActivityCard(
    Map<String, dynamic> log,
  ) {
    final action = (log['aksi'] ?? '').toString();

    final user = _asMap(log['pengguna']);

    final actor =
        (user?['nama'] ?? user?['email'] ?? 'System')
            .toString();

    final role = user?['role'] == 'admin_pemilik'
        ? 'Admin / Owner'
        : user?['role'] == 'kasir'
            ? 'Cashier'
            : 'System';

    final actionColor = _actionColor(action);

    final table = _tableLabel(log['nama_tabel']);

    final detail = _detailDescription(
      action,
      log['detail'],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: actionColor.withValues(
                alpha: 0.12,
              ),
              child: Icon(
                _actionIcon(action),
                color: actionColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _actionLabel(action),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildInfoChip(
                        icon: Icons.person_outline,
                        label: actor,
                      ),
                      _buildInfoChip(
                        icon: Icons.shield_outlined,
                        label: role,
                      ),
                      _buildInfoChip(
                        icon: Icons.table_chart_outlined,
                        label: table,
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .outline,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(log['waktu']),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.history_toggle_off_rounded,
          size: 54,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _searchController.text.trim().isEmpty
                ? 'No activity found.'
                : 'No matching activity found.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search activity...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadLogs,
              child: _isLoading
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                      ],
                    )
                  : filteredLogs.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24,
                          ),
                          itemCount: filteredLogs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildActivityCard(
                              filteredLogs[index],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
