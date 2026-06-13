import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

Future<Uint8List> buildPdfBytes(Map<String, dynamic> payload) async {
  final name = payload['name'] as String? ?? '';
  final dateFilter = payload['dateFilter'] as String? ?? 'All';
  final startIso = payload['start'] as String?;
  final endIso = payload['end'] as String?;
  final txs = (payload['txs'] as List).cast<Map<String, dynamic>>();

  final pdf = pw.Document();

  // Calculate totals
  final totalIn = txs
      .where((t) => t['type'] == 'income')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
  final totalOut = txs
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
  final netBalance = totalIn - totalOut;

  // Format currency helper
  final currencyFormat = NumberFormat.currency(symbol: 'TK ', decimalDigits: 2);

  // Parse and format date range
  String dateRangeStr = '';
  if (dateFilter == 'All') {
    dateRangeStr = 'All Time';
  } else if (dateFilter == 'Custom' && startIso != null && endIso != null) {
    try {
      final start = DateTime.parse(startIso);
      final end = DateTime.parse(endIso);
      dateRangeStr =
          '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
    } catch (_) {
      dateRangeStr = dateFilter;
    }
  } else {
    dateRangeStr = dateFilter;
  }

  final exportTime = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

  // Colors
  final primaryColor = PdfColor.fromHex('#1E3A8A'); // Dark Blue
  final primaryLight = PdfColor.fromHex('#EFF6FF'); // Very light blue
  final greenColor = PdfColor.fromHex('#047857'); // Emerald Green
  final greenBg = PdfColor.fromHex('#ECFDF5'); // Light green
  final greenBorder = PdfColor.fromHex('#A7F3D0');
  final redColor = PdfColor.fromHex('#B91C1C'); // Crimson Red
  final redBg = PdfColor.fromHex('#FEF2F2'); // Light red
  final redBorder = PdfColor.fromHex('#FECACA');
  final greyColor = PdfColor.fromHex('#64748B'); // Slate Grey
  final lightGreyColor = PdfColor.fromHex('#F1F5F9'); // Border/divider
  final zebraColor = PdfColor.fromHex('#F8FAFC'); // Alternating rows
  final textColor = PdfColor.fromHex('#1E293B');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          'CASHBOOK REPORT',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Exported: $exportTime',
                      style: pw.TextStyle(fontSize: 8, color: greyColor),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Period: $dateRangeStr',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: textColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: lightGreyColor),
            pw.SizedBox(height: 16),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: lightGreyColor),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '100% Safe & Secure | Auto Data Backup',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: greyColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: greyColor),
                ),
              ],
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          // 1. Overview Cards (Only on the first page, so it goes in build)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Total In Card
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 6),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: greenBg,
                    border: pw.Border.all(color: greenBorder, width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAL CASH IN',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: greenColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalIn),
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: greenColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Total Out Card
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: redBg,
                    border: pw.Border.all(color: redBorder, width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAL CASH OUT',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalOut),
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Net Balance Card
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(left: 6),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: primaryLight,
                    border: pw.Border.all(
                      color: netBalance >= 0 ? greenBorder : redBorder,
                      width: 1,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NET BALANCE',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: netBalance >= 0 ? greenColor : redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(netBalance),
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: netBalance >= 0 ? greenColor : redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // 2. Transaction List Title
          pw.Text(
            'Transaction History (${txs.length} entries)',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 8),

          // 3. Transactions Table
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2), // Date
              1: const pw.FlexColumnWidth(4.8), // Description
              2: const pw.FlexColumnWidth(2.0), // Type
              3: const pw.FlexColumnWidth(3.0), // Amount (Right-aligned)
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: pw.Text(
                      'Date',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: pw.Text(
                      'Remark / Description',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: pw.Text(
                      'Type',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Data Rows
              ...txs.asMap().entries.map((entry) {
                final index = entry.key;
                final t = entry.value;
                final isIncome = t['type'] == 'income';
                final rowColor = index % 2 == 0 ? zebraColor : PdfColors.white;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: rowColor,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: lightGreyColor, width: 0.5),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        t['date'].toString(),
                        style: pw.TextStyle(fontSize: 8.5, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        t['description'].toString(),
                        style: pw.TextStyle(fontSize: 8.5, color: textColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        isIncome ? 'Cash In' : 'Cash Out',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: isIncome ? greenColor : redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        currencyFormat.format((t['amount'] as num).toDouble()),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: isIncome ? greenColor : redColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ];
      },
    ),
  );

  final bytes = await pdf.save();
  return Uint8List.fromList(bytes);
}
