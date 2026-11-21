
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/report_repository.dart';
import 'report_preview_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final ReportRepository _repository;

  String _period = 'daily';
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _repository = ReportRepository(
      Supabase.instance.client,
    );

    _loadReport();
  }

  DateTime get _startDate {
    if (_period == 'monthly') {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        1,
      );
    }

    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
  }

  DateTime get _endDate {
    if (_period == 'monthly') {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        1,
      );
    }

    return _startDate.add(const Duration(days: 1));
  }

  List<Map<String, dynamic>> get _validTransactions {
    return _transactions.where((transaction) {
      return transaction['status_pesanan'] != 'dibatalkan';
    }).toList();
  }

  int get _cancelledCount {
    return _transactions.where((transaction) {
      return transaction['status_pesanan'] == 'dibatalkan';
    }).length;
  }

  double get _totalSales {
    return _validTransactions.fold<double>(
      0,
      (total, transaction) {
        return total + _toDouble(transaction['total']);
      },
    );
  }

  double get _cashSales {
    return _calculatePaymentTotal('tunai');
  }

  double get _nonCashSales {
    return _calculatePaymentTotal('non_tunai');
  }

  double _calculatePaymentTotal(String method) {
    double total = 0;

    for (final transaction in _validTransactions) {
      final payments = _asMapList(
        transaction['pembayaran'],
      );

      for (final payment in payments) {
        if (payment['metode'] == method) {
          total += _toDouble(payment['nominal']);
        }
      }
    }

    return total;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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

  Future<void> _loadReport() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _repository.fetchTransactions(
        startInclusive: _startDate,
        endExclusive: _endDate,
      );

      if (!mounted) return;

      setState(() {
        _transactions = result;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to load report: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: _period == 'daily'
          ? 'Select report date'
          : 'Select a date in the report month',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadReport();
  }

  void _changePeriod(String? value) {
    if (value == null) return;

    setState(() {
      _period = value;
    });

    _loadReport();
  }

  String _formatCurrency(num value) {
    final formatted = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatSelectedPeriod() {
    if (_period == 'monthly') {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${months[_selectedDate.month - 1]} '
          '${_selectedDate.year}';
    }

    return '${_twoDigits(_selectedDate.day)}/'
        '${_twoDigits(_selectedDate.month)}/'
        '${_selectedDate.year}';
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

  Color _statusColor(
    String status,
    BuildContext context,
  ) {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _openReportPreview() async {
    if (_isLoading) return;

    final reportTransactions = _transactions
        .map(
          (transaction) =>
              Map<String, dynamic>.from(transaction),
        )
        .toList(growable: false);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return ReportPreviewPage(
            period: _period,
            periodLabel: _formatSelectedPeriod(),
            generatedAt: DateTime.now(),
            transactions: reportTransactions,
            totalSales: _totalSales,
            transactionCount: _validTransactions.length,
            cashSales: _cashSales,
            nonCashSales: _nonCashSales,
            cancelledCount: _cancelledCount,
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final cardColor =
        color ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: cardColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
  ) {
    final code =
        (transaction['kode_transaksi'] ?? '-').toString();

    final status =
        (transaction['status_pesanan'] ?? '').toString();

    final color = _statusColor(status, context);

    final payments = _asMapList(
      transaction['pembayaran'],
    );

    final paymentMethod = payments.isEmpty
        ? '-'
        : payments.map((payment) {
            return payment['metode'] == 'tunai'
                ? 'Cash'
                : 'Non-cash';
          }).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          code,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(transaction['tanggal_transaksi']),
              ),
              const SizedBox(height: 3),
              Text('Payment: $paymentMethod'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  Chip(
                    label: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: color.withValues(
                      alpha: 0.10,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Text(
          _formatCurrency(_toDouble(transaction['total'])),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validTransactions = _validTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            onPressed: _isLoading ? null : _openReportPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Report Period',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(
                labelText: 'Report type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'daily',
                  child: Text('Daily Report'),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text('Monthly Report'),
                ),
              ],
              onChanged: _isLoading ? null : _changePeriod,
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _selectDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_formatSelectedPeriod()),
            ),

            const SizedBox(height: 20),

            Text(
              'Sales Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 10),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  _buildSummaryCard(
                    title: 'Total Sales',
                    value: _formatCurrency(_totalSales),
                    icon: Icons.payments_outlined,
                  ),
                  _buildSummaryCard(
                    title: 'Transactions',
                    value: '${validTransactions.length}',
                    icon: Icons.receipt_long_outlined,
                    color: Colors.teal,
                  ),
                  _buildSummaryCard(
                    title: 'Cash Sales',
                    value: _formatCurrency(_cashSales),
                    icon: Icons.money_outlined,
                    color: Colors.green,
                  ),
                  _buildSummaryCard(
                    title: 'Non-cash Sales',
                    value: _formatCurrency(_nonCashSales),
                    icon: Icons.account_balance_outlined,
                    color: Colors.indigo,
                  ),
                  _buildSummaryCard(
                    title: 'Cancelled',
                    value: '$_cancelledCount',
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                'Transaction Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 10),

              if (_transactions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Center(
                      child: Text(
                        'No transactions found for this period.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ..._transactions.map(_buildTransactionCard),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
