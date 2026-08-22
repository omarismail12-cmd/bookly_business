import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_service.dart';

/// Concrete [PdfService]: pure-Dart PDF generation via the `pdf` package.
/// Unlike Firebase/FCM, this needs no external project or credentials, so
/// it works fully offline in every build of this app.
class PdfDocumentService implements PdfService {
  @override
  Future<List<int>> createReceipt({required Map<String, dynamic> data}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (data['businessName'] as String?) ?? 'Bookly Business',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Payment receipt', style: const pw.TextStyle(color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              _row('Reference', (data['reference'] as String?) ?? '-'),
              _row('Date', (data['date'] as String?) ?? '-'),
              _row('Customer', (data['customerName'] as String?) ?? '-'),
              _row('Method', (data['method'] as String?) ?? '-'),
              _row('Type', (data['type'] as String?) ?? '-'),
              pw.Divider(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    (data['amount'] as String?) ?? '-',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Thank you for your business.',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  @override
  Future<List<int>> createReport({required Map<String, dynamic> data}) async {
    final doc = pw.Document();
    final staff = List<Map<String, dynamic>>.from(data['staffPerformance'] ?? []);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (data['businessName'] as String?) ?? 'Bookly Business',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Report • ${(data['period'] as String?) ?? ''}',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _stat('Occupancy', '${data['occupancyPercent'] ?? 0}%'),
                  _stat('Appointments', '${data['appointments'] ?? 0}'),
                  _stat('Completed', '${data['completed'] ?? 0}'),
                  _stat('No-shows', '${data['noShow'] ?? 0}'),
                  _stat('Revenue', (data['revenue'] as String?) ?? '-'),
                ],
              ),
              pw.SizedBox(height: 24),
              if (staff.isNotEmpty) ...[
                pw.Text('Staff performance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: const ['Staff', 'Completed', 'No-shows', 'Revenue'],
                  data: staff
                      .map(
                        (s) => [
                          '${s['display_name'] ?? ''}',
                          '${s['completed'] ?? 0}',
                          '${s['no_show'] ?? 0}',
                          '${s['revenue'] ?? '-'}',
                        ],
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value),
      ],
    ),
  );

  pw.Widget _stat(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
      pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
    ],
  );
}
