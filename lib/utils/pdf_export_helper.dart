import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildPdfBytes(Map<String, dynamic> payload) async {
  final name = payload['name'] as String? ?? '';
  final dateFilter = payload['dateFilter'] as String? ?? 'All';
  final startIso = payload['start'] as String?;
  final endIso = payload['end'] as String?;
  final txs = (payload['txs'] as List).cast<Map<String, dynamic>>();

  final pdf = pw.Document();

  final totalIn = txs
      .where((t) => t['type'] == 'income')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
  final totalOut = txs
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Cashbook Report: $name',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Date Range: $dateFilter'),
              if (dateFilter == 'Custom' && startIso != null && endIso != null)
                pw.Text('From: ${startIso}  To: ${endIso}'),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Description', 'Amount', 'Type'],
                data:
                    txs
                        .map(
                          (t) => [
                            t['date'].toString(),
                            t['description'].toString(),
                            '৳ ${(t['amount'] as num).toDouble().toStringAsFixed(2)}',
                            t['type'] == 'income' ? 'Income' : 'Expense',
                          ],
                        )
                        .toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellPadding: const pw.EdgeInsets.all(5),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Total Cash In:  ${totalIn.toStringAsFixed(2)}'),
              pw.Text('Total Cash Out:  ${totalOut.toStringAsFixed(2)}'),
              pw.Text(
                'Net Balance:  ${(totalIn - totalOut).toStringAsFixed(2)}',
              ),
            ],
          ),
    ),
  );

  final bytes = await pdf.save();
  return Uint8List.fromList(bytes);
}
