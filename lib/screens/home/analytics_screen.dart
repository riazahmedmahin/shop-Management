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

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedBookId = 'all';
  int _selectedDaysPeriod = 30; // 7 or 30 days
  bool _showBarChart = true; // Toggle between bar chart & donut chart
  int? _selectedBarIndex; // Currently tapped bar index for detailed breakdown

  // Helper to compute date range label
  String get _dateRangeLabel {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _selectedDaysPeriod - 1));
    return '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(now)}';
  }

  // Filtered transactions based on Selected Book and Selected Days Period
  List<Transaction> get _filteredTransactions {
    List<Transaction> txs = [];
    if (_selectedBookId == 'all') {
      txs = widget.cashbooks.expand((b) => b.transactions).toList();
    } else {
      final bookIndex = widget.cashbooks.indexWhere(
        (b) => b.id == _selectedBookId,
      );
      if (bookIndex != -1) {
        txs = widget.cashbooks[bookIndex].transactions;
      }
    }

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _selectedDaysPeriod - 1));

    // Include transactions that occurred on or after the start date
    final filtered =
        txs
            .where(
              (t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))),
            )
            .toList();

    // Sort transactions by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  // Daily statistics for the chart
  List<DailyStats> get _dailyStats {
    final txs = _filteredTransactions;
    final days = List.generate(_selectedDaysPeriod, (i) {
      final d = DateTime.now().subtract(
        Duration(days: _selectedDaysPeriod - 1 - i),
      );
      return DateTime(d.year, d.month, d.day);
    });

    return days.map((day) {
      final dayTxs = txs.where(
        (t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day,
      );

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
      final txMaps =
          txs
              .map(
                (t) => {
                  'id': t.id,
                  'description': t.description,
                  'amount': t.amount,
                  'type':
                      t.type == TransactionType.income ? 'income' : 'expense',
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
        'dateFilter': 'Last $_selectedDaysPeriod Days',
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
      final txMaps =
          txs
              .map(
                (t) => {
                  'id': t.id,
                  'description': t.description,
                  'amount': t.amount,
                  'type':
                      t.type == TransactionType.income ? 'income' : 'expense',
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
        'dateFilter': 'Last $_selectedDaysPeriod Days',
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

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBarChartSection(List<DailyStats> stats) {
    double maxVal = 0;
    for (var s in stats) {
      if (s.income > maxVal) maxVal = s.income;
      if (s.expense > maxVal) maxVal = s.expense;
    }
    final bool hasData = maxVal > 0;
    if (maxVal == 0) maxVal = 1000.0;

    // Standardize maxVal to nice rounded grid values (e.g. multiples of 1000 or 5000)
    double step = (maxVal / 3).ceilToDouble();
    if (step < 1) step = 1;
    final List<double> gridLines = [
      maxVal,
      maxVal - step,
      maxVal - 2 * step,
      0.0,
    ];

    Widget chartContent() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          final incomeHeight = (s.income / maxVal) * 120;
          final expenseHeight = (s.expense / maxVal) * 120;
          final isSelected = _selectedBarIndex == i;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedBarIndex = isSelected ? null : i;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Income bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _selectedDaysPeriod == 7 ? 12 : 8,
                        height:
                            s.income > 0
                                ? (incomeHeight < 4 ? 4 : incomeHeight)
                                : 0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                isSelected
                                    ? [Colors.green[700]!, Colors.green[400]!]
                                    : [Colors.green[500]!, Colors.green[300]!],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                  : [],
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Expense bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _selectedDaysPeriod == 7 ? 12 : 8,
                        height:
                            s.expense > 0
                                ? (expenseHeight < 4 ? 4 : expenseHeight)
                                : 0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                isSelected
                                    ? [Colors.red[700]!, Colors.red[400]!]
                                    : [Colors.red[500]!, Colors.red[300]!],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                  : [],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDaysPeriod == 7
                        ? DateFormat('E').format(s.date)
                        : DateFormat('d').format(s.date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.blueAccent : Colors.grey[700],
                    ),
                  ),
                  Text(
                    _selectedDaysPeriod == 7
                        ? DateFormat('dd').format(s.date)
                        : DateFormat('MMM').format(s.date),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? Colors.blueAccent[100]
                              : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cash Flow Trend (Last $_selectedDaysPeriod Days)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'In',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Out',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
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
                    'No transactions in this period',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                height: 160,
                child: Row(
                  children: [
                    // Y-Axis labels
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children:
                          gridLines.map((val) {
                            return Container(
                              height: 20,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                val >= 1000
                                    ? '৳${(val / 1000).toStringAsFixed(1)}k'
                                    : '৳${val.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    // Vertical Separator Line
                    Container(width: 1, color: Colors.grey[200]),
                    const SizedBox(width: 8),
                    // Scrollable/Static Chart Bars
                    Expanded(
                      child:
                          _selectedDaysPeriod == 30
                              ? ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  const SizedBox(width: 8),
                                  chartContent(),
                                  const SizedBox(width: 8),
                                ],
                              )
                              : chartContent(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChartSection(double totalIn, double totalOut) {
    final total = totalIn + totalOut;
    final savingsRate =
        totalIn > 0 ? ((totalIn - totalOut) / totalIn) * 100 : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flow Structure Breakdown',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (total == 0)
              Container(
                height: 150,
                child: const Center(
                  child: Text(
                    'No transactions in this period',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Donut Chart Custom Painter inside an animated builder
                  Expanded(
                    flex: 4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.fastOutSlowIn,
                      builder: (context, value, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CustomPaint(
                                painter: DonutChartPainter(
                                  income: totalIn,
                                  expense: totalOut,
                                  animationValue: value,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  savingsRate >= 0 ? 'Savings' : 'Deficit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${savingsRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        savingsRate >= 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          'Cash In',
                          Colors.green[500]!,
                          '৳ ${totalIn.toStringAsFixed(0)} ',
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          'Cash Out',
                          Colors.red[400]!,
                          '৳ ${totalOut.toStringAsFixed(0)}',
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Volume:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '৳ ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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

    // Daily stats for chart
    final stats = _dailyStats;

    // Tapped bar details (if index is selected and has data)
    DailyStats? activeBarData;
    if (_selectedBarIndex != null && _selectedBarIndex! < stats.length) {
      final potentialData = stats[_selectedBarIndex!];
      if (potentialData.income > 0 || potentialData.expense > 0) {
        activeBarData = potentialData;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cashbook Selector Dropdown
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
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
                              _selectedBarIndex =
                                  null; // Reset chart highlights
                            });
                          }
                        },
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Books Combined'),
                          ),
                          ...widget.cashbooks.map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7 Days / 30 Days Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[150] ?? Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDaysPeriod = 7;
                            _selectedBarIndex = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                _selectedDaysPeriod == 7
                                    ? Colors.white
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow:
                                _selectedDaysPeriod == 7
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Last 7 Days',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _selectedDaysPeriod == 7
                                      ? Colors.blueAccent
                                      : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDaysPeriod = 30;
                            _selectedBarIndex = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                _selectedDaysPeriod == 30
                                    ? Colors.white
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow:
                                _selectedDaysPeriod == 30
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Last 30 Days',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _selectedDaysPeriod == 30
                                      ? Colors.blueAccent
                                      : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Date Range Text Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    _dateRangeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Quick Stats Metrics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business Analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
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

            // Chart View Mode Selector (Trend vs Structure)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Visualizations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showBarChart = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _showBarChart
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.bar_chart,
                              size: 16,
                              color:
                                  _showBarChart
                                      ? Colors.white
                                      : Colors.grey[700],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showBarChart = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  !_showBarChart
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.pie_chart,
                              size: 16,
                              color:
                                  !_showBarChart
                                      ? Colors.white
                                      : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Active Chart Render
            _showBarChart
                ? _buildBarChartSection(stats)
                : _buildDonutChartSection(totalIn, totalOut),

            // Tap detailed breakdown card
            if (_showBarChart && activeBarData != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day Details: ${DateFormat('dd MMMM yyyy').format(activeBarData.date)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cash In: ৳${activeBarData.income.toStringAsFixed(2)}  |  Cash Out: ৳${activeBarData.expense.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:
                            () => setState(() => _selectedBarIndex = null),
                      ),
                    ],
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),

            // // Direct Transaction Verification List
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       const Text(
            //         'Transactions (this period)',
            //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            //       ),
            //       Text(
            //         '${txs.length} entries',
            //         style: const TextStyle(
            //           fontSize: 13,
            //           color: Colors.grey,
            //           fontWeight: FontWeight.w500,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // if (txs.isEmpty)
            //   Padding(
            //     padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            //     child: Center(
            //       child: Column(
            //         children: [
            //           Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
            //           const SizedBox(height: 8),
            //           const Text(
            //             'No transactions recorded in this period.',
            //             style: TextStyle(color: Colors.grey, fontSize: 13),
            //             textAlign: TextAlign.center,
            //           ),
            //         ],
            //       ),
            //     ),
            //   )
            // else
            //   ListView.builder(
            //     shrinkWrap: true,
            //     physics: const NeverScrollableScrollPhysics(),
            //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            //     itemCount: txs.length > 50 ? 50 : txs.length, // Limit preview in scrollable column for performance
            //     itemBuilder: (context, i) {
            //       final t = txs[i];
            //       return Card(
            //         margin: const EdgeInsets.only(bottom: 8),
            //         elevation: 0.5,
            //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            //         child: ListTile(
            //           dense: true,
            //           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            //           title: Text(
            //             t.description,
            //             style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            //           ),
            //           subtitle: Text(
            //             DateFormat('dd MMM yyyy, hh:mm a').format(t.date),
            //             style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            //           ),
            //           trailing: Text(
            //             '৳ ${t.amount.toStringAsFixed(2)}',
            //             style: TextStyle(
            //               fontWeight: FontWeight.bold,
            //               fontSize: 13,
            //               color: t.type == TransactionType.income ? Colors.green[700] : Colors.red[700],
            //             ),
            //           ),
            //         ),
            //       );
            //     },
            //   ),

            // if (txs.length > 50)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            //     child: Center(
            //       child: Text(
            //         'Showing last 50 transactions. Export as PDF or Excel to view all.',
            //         style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            //       ),
            //     ),
            //   ),

            // const Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Divider(),
            // ),

            // Export Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Reports',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('PDF Report'),
                          onPressed:
                              txs.isEmpty ? null : () => _generatePdf(txs),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Excel (CSV)'),
                          onPressed:
                              txs.isEmpty ? null : () => _generateExcel(txs),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
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

// Custom Painter for Donut Chart
class DonutChartPainter extends CustomPainter {
  final double income;
  final double expense;
  final double animationValue;

  DonutChartPainter({
    required this.income,
    required this.expense,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;

    final total = income + expense;

    if (total == 0) {
      paint.color = Colors.grey[200]!;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final incomeAngle = (income / total) * 360 * (3.141592653589793 / 180);
    final expenseAngle = (expense / total) * 360 * (3.141592653589793 / 180);

    // Start drawing from the top (-90 degrees)
    double startAngle = -3.141592653589793 / 2;

    // Draw Income arc
    if (income > 0) {
      paint.color = Colors.green[500]!;
      final sweep = incomeAngle * animationValue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // Draw Expense arc
    if (expense > 0) {
      paint.color = Colors.red[400]!;
      final sweep = expenseAngle * animationValue;
      final expenseStart =
          income > 0
              ? (-3.141592653589793 / 2) + (incomeAngle * animationValue)
              : -3.141592653589793 / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        expenseStart,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.income != income ||
        oldDelegate.expense != expense ||
        oldDelegate.animationValue != animationValue;
  }
}
