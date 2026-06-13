import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/utils/pdf_export_helper.dart';

void main() {
  test('buildPdfBytes generates valid PDF bytes', () async {
    final payload = {
      'name': 'Test Cashbook',
      'dateFilter': 'All',
      'txs': [
        {
          'date': '13 Jun 2026',
          'description': 'Salary',
          'amount': 15000.00,
          'type': 'income',
        },
        {
          'date': '13 Jun 2026',
          'description': 'Office Rent',
          'amount': 5000.00,
          'type': 'expense',
        }
      ],
    };

    final bytes = await buildPdfBytes(payload);
    expect(bytes, isNotNull);
    expect(bytes.isNotEmpty, isTrue);
  });
}
