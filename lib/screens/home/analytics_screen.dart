import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/transaction.dart';
import '../../models/cashbook.dart';
import '../../utils/pdf_export_helper.dart';
import '../../utils/csv_export_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<Cashbook> cashbooks;

  const AnalyticsScreen({super.key, required this.cashbooks});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class DailyStats {
  final DateTime date;
  final double income;
  final double expense;
  DailyStats(this.date, this.income, this.expense);
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedBookId = 'all';

  List<Transaction> get _filteredTransactions {
    if (_selectedBookId == 'all') {
      return widget.cashbooks.expand((b) => b.transactions).toList();
    } else {
      final bookIndex = widget.cashbooks.indexWhere((b) => b.id == _selectedBookId);
      if (bookIndex != -1) {
        return widget.cashbooks[bookIndex].transactions;
      }
      return [];
    }
  }

  List<DailyStats> get _dailyStats {
    final txs = _filteredTransactions;
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return days.map((day) {
      final dayTxs = txs.where((t) =>
          t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day);

      double income = 0;
      double expense = 0;
      for (var t in dayTxs) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return DailyStats(day, income, expense);
    }).toList();
  }

  Future<void> _generatePdf(List<Transaction> txs) async {
    try {
      final txMaps = txs
          .map(
            (t) => {
              'id': t.id,
              'description': t.description,
              'amount': t.amount,
              'type': t.type == TransactionType.income ? 'income' : 'expense',
              'date': DateFormat('dd MMM yyyy').format(t.date),
            },
          )
          .toList();

      String bookName = 'All Books';
      if (_selectedBookId != 'all') {
        final b = widget.cashbooks.firstWhere((x) => x.id == _selectedBookId);
        bookName = b.name;
      }

      final payload = {
        'name': bookName,
        'dateFilter': 'All',
        'start': null,
        'end': null,
        'txs': txMaps,
      };

      final bytes = await compute(buildPdfBytes, payload);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF saved: ${file.path}')));
      }
      OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    }
  }

  Future<void> _generateExcel(List<Transaction> txs) async {
    try {
      final txMaps = txs
          .map(
            (t) => {
              'id': t.id,
              'description': t.description,
              'amount': t.amount,
              'type': t.type == TransactionType.income ? 'income' : 'expense',
              'date': DateFormat('dd MMM yyyy').format(t.date),
            },
          )
          .toList();

      String bookName = 'All Books';
      if (_selectedBookId != 'all') {
        final b = widget.cashbooks.firstWhere((x) => x.id == _selectedBookId);
        bookName = b.name;
      }

      final payload = {
        'name': bookName,
        'dateFilter': 'All',
        'start': null,
        'end': null,
        'txs': txMaps,
      };

      final csv = await compute(buildCsvString, payload);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel saved: ${file.path}')));
      }
      OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel error: $e')));
      }
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildChart(List<DailyStats> stats) {
    double maxVal = 0;
    for (var s in stats) {
      if (s.income > maxVal) maxVal = s.income;
      if (s.expense > maxVal) maxVal = s.expense;
    }
    final bool hasData = maxVal > 0;
    if (maxVal == 0) maxVal = 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cash Flow (Last 7 Days)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem('In', Colors.green),
                    const SizedBox(width: 8),
                    _buildLegendItem('Out', Colors.red),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!hasData)
              Container(
                height: 150,
                child: const Center(
                  child: Text(
                    'No transactions in the last 7 days',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stats.map((s) {
                  final incomeHeight = (s.income / maxVal) * 100;
                  final expenseHeight = (s.expense / maxVal) * 100;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Income bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 8,
                            height: s.income > 0
                                ? (incomeHeight < 4 ? 4 : incomeHeight)
                                : 0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green[600]!,
                                  Colors.green[300]!
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(3),
                                topRight: Radius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          // Expense bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 8,
                            height: s.expense > 0
                                ? (expenseHeight < 4 ? 4 : expenseHeight)
                                : 0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.red[300]!],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(3),
                                topRight: Radius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('E').format(s.date),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('dd').format(s.date),
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = _filteredTransactions;
    final totalIn = txs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalOut = txs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;
    final count = txs.length;

    // Daily stats for graph
    final stats = _dailyStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Cashbook',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBookId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBookId = val;
                            });
                          }
                        },
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Books Combined'),
                          ),
                          ...widget.cashbooks.map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(b.name),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business Analytics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Income',
                          value: '৳ ${totalIn.toStringAsFixed(2)}',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Total Expense',
                          value: '৳ ${totalOut.toStringAsFixed(2)}',
                          icon: Icons.trending_down,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Net Balance',
                          value: '৳ ${net.toStringAsFixed(2)}',
                          icon: Icons.account_balance,
                          color: net >= 0 ? Colors.blue : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Transactions',
                          value: count.toString(),
                          icon: Icons.receipt_long,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chart Widget
            _buildChart(stats),

            const Divider(),

            // Export Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Filtered as PDF'),
                      onPressed: txs.isEmpty ? null : () => _generatePdf(txs),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Filtered as Excel (CSV)'),
                      onPressed: txs.isEmpty ? null : () => _generateExcel(txs),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
