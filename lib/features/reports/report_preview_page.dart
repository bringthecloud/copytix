
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPreviewPage extends StatelessWidget {
  const ReportPreviewPage({
    required this.period,
    required this.periodLabel,
    required this.generatedAt,
    required this.transactions,
    required this.totalSales,
    required this.transactionCount,
    required this.cashSales,
    required this.nonCashSales,
    required this.cancelledCount,
    super.key,
  });

  final String period;
  final String periodLabel;
  final DateTime generatedAt;
  final List<Map<String, dynamic>> transactions;

  final double totalSales;
  final int transactionCount;
  final double cashSales;
  final double nonCashSales;
  final int cancelledCount;

  static const PdfColor _primaryColor = PdfColor(
    0.459,
    0.396,
    0.8,
  );

  String get _fileName {
    final safePeriod = periodLabel.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );

    return 'Copytix_Sales_Report_${period}_$safePeriod.pdf';
  }

  String _formatCurrency(num value) {
    final formatted = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) return '-';

    final date = parsed.toLocal();

    String twoDigits(int number) =>
        number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
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

  String _paymentMethodLabel(dynamic value) {
    switch (value?.toString()) {
      case 'tunai':
        return 'Cash';
      case 'non_tunai':
        return 'Non-cash';
      default:
        return '-';
    }
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

  pw.Widget _tableCell(
    String value, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 7,
      ),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isTotal
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isTotal
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: isTotal ? _primaryColor : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdf(
    PdfPageFormat format,
  ) async {
    final pdf = pw.Document();

    final summaryRows = [
      ['Total Sales', _formatCurrency(totalSales)],
      ['Transactions', '$transactionCount'],
      ['Cash Sales', _formatCurrency(cashSales)],
      ['Non-cash Sales', _formatCurrency(nonCashSales)],
      ['Cancelled', '$cancelledCount'],
    ];

    final transactionRows = transactions.map((transaction) {
      final payments = _asMapList(
        transaction['pembayaran'],
      );

      final paymentMethod = payments.isEmpty
          ? '-'
          : payments
              .map(
                (payment) =>
                    _paymentMethodLabel(payment['metode']),
              )
              .toSet()
              .join(', ');

      final status =
          (transaction['status_pesanan'] ?? '').toString();

      return pw.TableRow(
        children: [
          _tableCell(
            _formatDate(transaction['tanggal_transaksi']),
          ),
          _tableCell(
            (transaction['kode_transaksi'] ?? '-').toString(),
          ),
          _tableCell(paymentMethod),
          _tableCell(_statusLabel(status)),
          _tableCell(
            _formatCurrency(
              _toDouble(transaction['total']),
            ),
          ),
        ],
      );
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),

        header: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Text(
              'COPYTIX | STUDIO & FOTOCOPY ANDRY',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          );
        },

        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          );
        },

        build: (context) {
          return [
            pw.Text(
              'Sales Report',
              style: pw.TextStyle(
                fontSize: 23,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Text(
              'Report Type: ${period == 'daily' ? 'Daily Report' : 'Monthly Report'}',
              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 4),

            pw.Text(
              'Report Period: $periodLabel',
              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 4),

            pw.Text(
              'Generated: ${_formatDate(generatedAt.toIso8601String())}',
              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              'Sales Summary',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey300,
                  width: 0.6,
                ),
              ),
              child: pw.Column(
                children: [
                  for (int index = 0;
                      index < summaryRows.length;
                      index++)
                    _summaryRow(
                      summaryRows[index][0],
                      summaryRows[index][1],
                      isTotal: index == 0,
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 22),

            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            if (transactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                ),
                child: pw.Text(
                  'No transactions found for this period.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.8),
                  1: const pw.FlexColumnWidth(2.6),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.4),
                  4: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _tableCell('Date', isHeader: true),
                      _tableCell(
                        'Transaction ID',
                        isHeader: true,
                      ),
                      _tableCell('Payment', isHeader: true),
                      _tableCell('Status', isHeader: true),
                      _tableCell('Total', isHeader: true),
                    ],
                  ),
                  ...transactionRows,
                ],
              ),

            pw.SizedBox(height: 22),

            pw.Divider(color: PdfColors.grey400),

            pw.SizedBox(height: 5),

            pw.Center(
              child: pw.Text(
                'Generated by Copytix',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report Preview'),
      ),
      body: PdfPreview(
        build: _buildPdf,
        pdfFileName: _fileName,
        initialPageFormat: PdfPageFormat.a4.landscape,
        allowPrinting: false,
        allowSharing: true,
      ),
    );
  }
}
