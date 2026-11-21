
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/transaction_repository.dart';
import 'receipt_preview_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState
    extends State<TransactionHistoryPage> {
  late final TransactionRepository _repository;

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _transactions = [];

  String _statusFilter = 'all';
  bool _isLoading = true;
  final Set<String> _updatingTransactions = {};

  @override
  void initState() {
    super.initState();

    _repository = TransactionRepository(
      Supabase.instance.client,
    );

    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await _repository.fetchHistory();

      if (!mounted) return;

      setState(() {
        _transactions = result;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to load transactions: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    final keyword = _searchController.text.trim().toLowerCase();

    return _transactions.where((transaction) {
      final code =
          (transaction['kode_transaksi'] ?? '')
              .toString()
              .toLowerCase();

      final status =
          (transaction['status_pesanan'] ?? '').toString();

      final matchesKeyword =
          keyword.isEmpty || code.contains(keyword);

      final matchesStatus =
          _statusFilter == 'all' || status == _statusFilter;

      return matchesKeyword && matchesStatus;
    }).toList();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'diproses':
        return 'Processing';
      case 'selesai':
        return 'Completed';
      case 'diambil':
        return 'Collected';
      case 'dibatalkan':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (status) {
      case 'diproses':
        return scheme.primary;
      case 'selesai':
        return Colors.green;
      case 'diambil':
        return Colors.teal;
      case 'dibatalkan':
        return scheme.error;
      default:
        return scheme.outline;
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = value is num
        ? value.round()
        : (int.tryParse(value?.toString() ?? '') ?? 0);

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');

    if (parsed == null) {
      return '-';
    }

    final date = parsed.toLocal();

    String twoDigits(int number) =>
        number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  List<Map<String, String>> _availableActions(String status) {
    switch (status) {
      case 'diproses':
        return [
          {
            'status': 'selesai',
            'label': 'Mark as Completed',
          },
          {
            'status': 'dibatalkan',
            'label': 'Cancel Transaction',
          },
        ];

      case 'selesai':
        return [
          {
            'status': 'diambil',
            'label': 'Mark as Collected',
          },
        ];

      default:
        return [];
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> transaction,
    String newStatus,
  ) async {
    final transactionId =
        transaction['id_transaksi']?.toString();

    final transactionCode =
        transaction['kode_transaksi']?.toString() ?? '-';

    if (transactionId == null || transactionId.isEmpty) {
      _showMessage('Invalid transaction ID.');
      return;
    }

    if (newStatus == 'dibatalkan') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cancel Transaction?'),
            content: Text(
              'Are you sure you want to cancel $transactionCode?\n\n'
              'The inventory deducted by this transaction will be restored.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Keep Transaction'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Confirm Cancellation'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _updatingTransactions.add(transactionId);
    });

    try {
      await _repository.updateStatus(
        transactionId: transactionId,
        status: newStatus,
      );

      if (!mounted) return;

      _showMessage(
        'Transaction $transactionCode updated to '
        '${_statusLabel(newStatus)}.',
      );

      await _loadTransactions();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to update transaction: $error');
    } finally {
      if (mounted) {
        setState(() {
          _updatingTransactions.remove(transactionId);
        });
      }
    }
  }

  Future<void> _showDetails(
    Map<String, dynamic> transaction,
  ) async {
    final transactionId =
        transaction['id_transaksi']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      _showMessage('Invalid transaction ID.');
      return;
    }

    try {
      final latest = await _repository.fetchById(transactionId);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _TransactionDetailDialog(
            transaction: latest,
            formatCurrency: _formatCurrency,
            formatDate: _formatDate,
            statusLabel: _statusLabel,
            availableActions: _availableActions,
            onStatusSelected: (status) {
              Navigator.of(dialogContext).pop();
              _changeStatus(latest, status);
            },
            onViewReceipt: () {
              Navigator.of(dialogContext).pop();

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceiptPreviewPage(
                    transaction: latest,
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to load transaction details: $error',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status, context);

    return Chip(
      label: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(
        color: color.withValues(alpha: 0.30),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
  ) {
    final code =
        (transaction['kode_transaksi'] ?? '-').toString();

    final status =
        (transaction['status_pesanan'] ?? '').toString();

    final transactionId =
        transaction['id_transaksi']?.toString() ?? '';

    final isUpdating =
        _updatingTransactions.contains(transactionId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          code,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(transaction['tanggal_transaksi']),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(transaction['total']),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildStatusChip(status),
            ],
          ),
        ),
        trailing: isUpdating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: isUpdating
            ? null
            : () => _showDetails(transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadTransactions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search transaction code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Transactions'),
                ),
                DropdownMenuItem(
                  value: 'diproses',
                  child: Text('Processing'),
                ),
                DropdownMenuItem(
                  value: 'selesai',
                  child: Text('Completed'),
                ),
                DropdownMenuItem(
                  value: 'diambil',
                  child: Text('Collected'),
                ),
                DropdownMenuItem(
                  value: 'dibatalkan',
                  child: Text('Cancelled'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _statusFilter = value;
                });
              },
            ),

            const SizedBox(height: 20),

            Text(
              'Transactions (${transactions.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (transactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No transactions found.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...transactions.map(_buildTransactionCard),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailDialog extends StatelessWidget {
  const _TransactionDetailDialog({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
    required this.statusLabel,
    required this.availableActions,
    required this.onStatusSelected,
    required this.onViewReceipt,
  });

  final Map<String, dynamic> transaction;
  final String Function(dynamic) formatCurrency;
  final String Function(dynamic) formatDate;
  final String Function(String) statusLabel;
  final List<Map<String, String>> Function(String) availableActions;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback onViewReceipt;

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

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    if (value is Map) {
      return [Map<String, dynamic>.from(value)];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final code =
        (transaction['kode_transaksi'] ?? '-').toString();

    final status =
        (transaction['status_pesanan'] ?? '').toString();

    final items = _asMapList(
      transaction['detail_transaksi'],
    );

    final payment = _asMap(
      transaction['pembayaran'],
    );

    final notes =
        (transaction['catatan'] ?? '').toString();

    final actions = availableActions(status);

    return AlertDialog(
      title: Text(code),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Date: ${formatDate(transaction['tanggal_transaksi'])}',
              ),
              const SizedBox(height: 6),
              Text('Status: ${statusLabel(status)}'),
              const SizedBox(height: 16),

              const Divider(),

              Text(
                'Service Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (items.isEmpty)
                const Text('No service details found.')
              else
                ...items.map((item) {
                  final service = _asMap(item['layanan']);

                  final serviceName =
                      (service?['nama_layanan'] ?? 'Service')
                          .toString();

                  final quantity = item['jumlah'] ?? 0;
                  final unitPrice = item['harga_satuan'] ?? 0;
                  final subtotal = item['subtotal'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$quantity × ${formatCurrency(unitPrice)}',
                        ),
                        Text(
                          'Subtotal: ${formatCurrency(subtotal)}',
                        ),
                      ],
                    ),
                  );
                }),

              const Divider(),

              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (payment == null)
                const Text('No payment details found.')
              else ...[
                Text(
                  'Method: ${payment['metode'] == 'tunai' ? 'Cash' : 'Non-cash'}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: ${formatCurrency(payment['nominal'])}',
                ),
                Text(
                  'Received: ${formatCurrency(payment['uang_diterima'])}',
                ),
                Text(
                  'Change: ${formatCurrency(payment['kembalian'])}',
                ),
                if (payment['tanggal_pembayaran'] != null)
                  Text(
                    'Payment date: ${formatDate(payment['tanggal_pembayaran'])}',
                  ),
              ],

              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Grand Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatCurrency(transaction['total']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),

              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(notes),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewReceipt,
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                  ),
                  label: const Text(
                    'Preview / Share PDF Receipt',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
        ...actions.map((action) {
          final nextStatus = action['status']!;
          final isCancellation = nextStatus == 'dibatalkan';

          return TextButton(
            onPressed: () {
              onStatusSelected(nextStatus);
            },
            style: isCancellation
                ? TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(action['label']!),
          );
        }),
      ],
    );
  }
}
