
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPreviewPage extends StatelessWidget {
  const ReceiptPreviewPage({
    required this.transaction,
    super.key,
  });

  final Map<String, dynamic> transaction;

  static const PdfColor _primaryColor = PdfColor(
    0.459,
    0.396,
    0.8,
  );

  String get _fileName {
    final code =
        (transaction['kode_transaksi'] ?? 'transaction')
            .toString()
            .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

    return 'Copytix_Receipt_$code.pdf';
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

  String _formatCurrency(dynamic value) {
    final amount = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

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

  String _paymentMethodLabel(dynamic method) {
    switch (method?.toString()) {
      case 'tunai':
        return 'Cash';
      case 'non_tunai':
        return 'Non-cash';
      default:
        return '-';
    }
  }

  pw.Widget _centered(
    pw.Widget child,
    double width,
  ) {
    return pw.Center(
      child: pw.Container(
        width: width,
        child: child,
      ),
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 7,
      ),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: bold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
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

    final items = _asMapList(
      transaction['detail_transaksi'],
    );

    final payment = _asMap(
      transaction['pembayaran'],
    );

    final pageWidth = math.min(
      format.availableWidth,
      280.0,
    );

    final transactionCode =
        (transaction['kode_transaksi'] ?? '-').toString();

    final status =
        (transaction['status_pesanan'] ?? '').toString();

    final notes =
        (transaction['catatan'] ?? '').toString();

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
        ),
        children: [
          _tableCell('Service', bold: true),
          _tableCell(
            'Qty',
            bold: true,
            align: pw.TextAlign.center,
          ),
          _tableCell(
            'Subtotal',
            bold: true,
            align: pw.TextAlign.right,
          ),
        ],
      ),
      ...items.map((item) {
        final service = _asMap(item['layanan']);

        final serviceName =
            (service?['nama_layanan'] ?? 'Service').toString();

        final unit =
            (service?['satuan'] ?? '').toString();

        final unitPrice =
            _formatCurrency(item['harga_satuan']);

        final quantity =
            (item['jumlah'] ?? 0).toString();

        final subtotal =
            _formatCurrency(item['subtotal']);

        final serviceDescription = unit.isEmpty
            ? '$serviceName\nUnit price: $unitPrice'
            : '$serviceName ($unit)\nUnit price: $unitPrice';

        return pw.TableRow(
          children: [
            _tableCell(serviceDescription),
            _tableCell(
              quantity,
              align: pw.TextAlign.center,
            ),
            _tableCell(
              subtotal,
              align: pw.TextAlign.right,
            ),
          ],
        );
      }),
    ];

    final content = <pw.Widget>[
      _centered(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'STUDIO & FOTOCOPY ANDRY',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'COPYTIX - PAYMENT RECEIPT',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(
              color: PdfColors.grey500,
              thickness: 0.8,
            ),
          ],
        ),
        pageWidth,
      ),

      _centered(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _summaryRow('Transaction Code', transactionCode),
            _summaryRow(
              'Date',
              _formatDate(transaction['tanggal_transaksi']),
            ),
            _summaryRow(
              'Status',
              _statusLabel(status),
            ),
          ],
        ),
        pageWidth,
      ),

      pw.SizedBox(height: 12),

      _centered(
        pw.Text(
          'ORDER DETAILS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pageWidth,
      ),

      pw.SizedBox(height: 6),

      _centered(
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(3.5),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(2),
          },
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          children: tableRows,
        ),
        pageWidth,
      ),

      pw.SizedBox(height: 12),

      _centered(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Divider(
              color: PdfColors.grey500,
              thickness: 0.8,
            ),
            _summaryRow(
              'Grand Total',
              _formatCurrency(transaction['total']),
              bold: true,
              color: _primaryColor,
            ),
          ],
        ),
        pageWidth,
      ),

      pw.SizedBox(height: 12),

      _centered(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'PAYMENT DETAILS',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            _summaryRow(
              'Payment Method',
              _paymentMethodLabel(payment?['metode']),
            ),
            _summaryRow(
              'Amount',
              _formatCurrency(payment?['nominal']),
            ),
            _summaryRow(
              'Amount Received',
              _formatCurrency(payment?['uang_diterima']),
            ),
            _summaryRow(
              'Change',
              _formatCurrency(payment?['kembalian']),
            ),
            if (payment?['tanggal_pembayaran'] != null)
              _summaryRow(
                'Payment Date',
                _formatDate(payment?['tanggal_pembayaran']),
              ),
          ],
        ),
        pageWidth,
      ),

      if (notes.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        _centered(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(
                color: PdfColors.grey400,
              ),
              pw.Text(
                'Notes',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                notes,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pageWidth,
        ),
      ],

      pw.SizedBox(height: 20),

      _centered(
        pw.Column(
          children: [
            pw.Divider(
              color: PdfColors.grey400,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Thank you for your visit!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated by Copytix',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pageWidth,
      ),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => content,
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
      ),
      body: PdfPreview(
        build: _buildPdf,
        pdfFileName: _fileName,
        allowPrinting: false,
        allowSharing: true,
      ),
    );
  }
}
