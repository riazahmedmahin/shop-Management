import 'package:csv/csv.dart';

String buildCsvString(Map<String, dynamic> payload) {
  final name = payload['name'] as String? ?? '';
  final dateFilter = payload['dateFilter'] as String? ?? 'All';
  final startIso = payload['start'] as String?;
  final endIso = payload['end'] as String?;
  final txs = (payload['txs'] as List).cast<Map<String, dynamic>>();

  List<List<dynamic>> csvData = [
    ['Cashbook Report: $name'],
    ['Date Range: $dateFilter'],
  ];
  if (dateFilter == 'Custom' && startIso != null && endIso != null) {
    csvData.add(['From: $startIso', 'To: $endIso']);
  }
  csvData.add([]);
  csvData.add(['Date', 'Description', 'Amount', 'Type']);

  for (var t in txs) {
    csvData.add([
      t['date'].toString(),
      t['description'].toString(),
      (t['amount'] as num).toDouble().toStringAsFixed(2),
      t['type'] == 'income' ? 'Income' : 'Expense',
    ]);
  }

  csvData.addAll([
    [],
    [
      'Total Cash In',
      txs
          .where((t) => t['type'] == 'income')
          .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble())
          .toStringAsFixed(2),
    ],
    [
      'Total Cash Out',
      txs
          .where((t) => t['type'] == 'expense')
          .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble())
          .toStringAsFixed(2),
    ],
    [
      'Net Balance',
      (txs
                  .where((t) => t['type'] == 'income')
                  .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()) -
              txs
                  .where((t) => t['type'] == 'expense')
                  .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()))
          .toStringAsFixed(2),
    ],
  ]);

  return const ListToCsvConverter().convert(csvData);
}
