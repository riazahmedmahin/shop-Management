import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/transaction.dart';
import '../../models/cashbook.dart';
import '../../utils/pdf_export_helper.dart';
import '../../utils/csv_export_helper.dart';

class BookDetailsScreen extends StatefulWidget {
  final Cashbook cashbook;
  final Function(Transaction) onAddTransaction;
  final Function(Transaction) onUpdateTransaction;
  final Function(List<String>) onDeleteTransactions;

  const BookDetailsScreen({
    super.key,
    required this.cashbook,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransactions,
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  String _searchQuery = '';
  String _dateFilter = 'All';
  String _typeFilter = 'All';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isMulti = false;
  final Set<String> _selectedIds = {};

  List<Transaction> get _filtered {
    List<Transaction> f = widget.cashbook.transactions;
    if (_searchQuery.isNotEmpty) {
      f =
          f
              .where(
                (t) => t.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }
    final now = DateTime.now();
    if (_dateFilter == 'This Day') {
      f =
          f
              .where(
                (t) =>
                    t.date.year == now.year &&
                    t.date.month == now.month &&
                    t.date.day == now.day,
              )
              .toList();
    } else if (_dateFilter == 'This Week') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      f =
          f
              .where(
                (t) => t.date.isAfter(start.subtract(const Duration(days: 1))),
              )
              .toList();
    } else if (_dateFilter == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      f =
          f
              .where(
                (t) => t.date.isAfter(start.subtract(const Duration(days: 1))),
              )
              .toList();
    } else if (_dateFilter == 'Custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      f =
          f
              .where(
                (t) =>
                    t.date.isAfter(
                      _customStartDate!.subtract(const Duration(days: 1)),
                    ) &&
                    t.date.isBefore(
                      _customEndDate!.add(const Duration(days: 1)),
                    ),
              )
              .toList();
    }
    if (_typeFilter == 'Cash In') {
      f = f.where((t) => t.type == TransactionType.income).toList();
    } else if (_typeFilter == 'Cash Out') {
      f = f.where((t) => t.type == TransactionType.expense).toList();
    }
    return f;
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

      final payload = {
        'name': widget.cashbook.name,
        'dateFilter': _dateFilter,
        'start': _customStartDate?.toIso8601String(),
        'end': _customEndDate?.toIso8601String(),
        'txs': txMaps,
      };

      final bytes = await compute(buildPdfBytes, payload);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF saved: ${file.path}')));
      }
      OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
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

      final payload = {
        'name': widget.cashbook.name,
        'dateFilter': _dateFilter,
        'start': _customStartDate?.toIso8601String(),
        'end': _customEndDate?.toIso8601String(),
        'txs': txMaps,
      };

      final csv = await compute(buildCsvString, payload);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cashbook_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel saved: ${file.path}')));
      }
      OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel error: $e')));
      }
    }
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txs = _filtered;
    final totalIn = txs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalOut = txs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        leading:
            _isMulti
                ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed:
                      () => setState(() {
                        _isMulti = false;
                        _selectedIds.clear();
                      }),
                )
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
        title:
            _isMulti
                ? Text('${_selectedIds.length} selected')
                : Text(widget.cashbook.name),
        actions:
            _isMulti
                ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed:
                        _selectedIds.isEmpty
                            ? null
                            : () {
                                _confirmDelete();
                              },
                  ),
                ]
                : [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () => _generatePdf(txs),
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_chart),
                    onPressed: () => _generateExcel(txs),
                  ),
                ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by remark...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (_dateFilter != 'All')
                    Chip(
                      label: Text(
                        _dateFilter,
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted:
                          () => setState(() {
                            _dateFilter = 'All';
                            _customStartDate = null;
                            _customEndDate = null;
                          }),
                    ),
                  if (_typeFilter != 'All')
                    Chip(
                      label: Text(
                        _typeFilter,
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () => setState(() => _typeFilter = 'All'),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              'Showing ${txs.length} of ${widget.cashbook.transactions.length} entries',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.green),
                            const Text('Total Cash In'),
                            Text(
                              '৳ ${totalIn.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.red),
                            const Text('Total Cash Out'),
                            Text(
                              '৳ ${totalOut.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Balance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '৳ ${(totalIn - totalOut).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                (totalIn - totalOut) >= 0
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Only you can see these entries',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                txs.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Try adding your first entry',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Icon(
                            Icons.arrow_downward,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: txs.length,
                      itemBuilder: (_, i) {
                        final t = txs[i];
                        final sel = _selectedIds.contains(t.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: sel ? Colors.blue[50] : null,
                          child: ListTile(
                            leading:
                                _isMulti
                                    ? Checkbox(
                                      value: sel,
                                      onChanged:
                                          (v) => setState(() {
                                            v == true
                                                ? _selectedIds.add(t.id)
                                                : _selectedIds.remove(t.id);
                                          }),
                                    )
                                    : null,
                            title: Text(t.description),
                            subtitle: Text(
                              DateFormat(
                                'MMMM dd yyyy\nhh:mm a',
                              ).format(t.date),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '৳ ${t.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        t.type == TransactionType.income
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                                const Text(
                                  'Final',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (_isMulti) {
                                setState(() {
                                  sel
                                      ? _selectedIds.remove(t.id)
                                      : _selectedIds.add(t.id);
                                });
                              } else {
                                _editTx(t);
                              }
                            },
                            onLongPress:
                                () => setState(() {
                                  _isMulti = true;
                                  _selectedIds.add(t.id);
                                }),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addTxDialog(TransactionType.income),
                    icon: const Icon(Icons.add),
                    label: const Text('CASH IN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addTxDialog(TransactionType.expense),
                    icon: const Icon(Icons.remove),
                    label: const Text('CASH OUT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Transactions'),
            content: Text(
              'Are you sure you want to delete ${_selectedIds.length} transaction(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  widget.onDeleteTransactions(_selectedIds.toList());
                  setState(() {
                    _isMulti = false;
                    _selectedIds.clear();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _openFilters() {
    String d = _dateFilter;
    String t = _typeFilter;
    DateTime? s = _customStartDate;
    DateTime? e = _customEndDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, setSB) => Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Date Range',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _chipBtn('This Day', d, (v) => setSB(() => d = v)),
                          _chipBtn('This Week', d, (v) => setSB(() => d = v)),
                          _chipBtn('This Month', d, (v) => setSB(() => d = v)),
                          _chipBtn('Custom', d, (v) async {
                            setSB(() => d = v);
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                              initialDateRange:
                                  (s != null && e != null)
                                      ? DateTimeRange(start: s!, end: e!)
                                      : null,
                            );
                            if (picked != null) {
                              setSB(() {
                                s = picked.start;
                                e = picked.end;
                              });
                            }
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Filter by',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _chipBtn('Cash Out', t, (v) => setSB(() => t = v)),
                          _chipBtn('Cash In', t, (v) => setSB(() => t = v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _dateFilter = d;
                              _typeFilter = t;
                              _customStartDate = s;
                              _customEndDate = e;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)
                            )
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _chipBtn(String text, String current, Function(String) onPressed) {
    final selected = text == current;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: OutlinedButton(
          onPressed: () => onPressed(text),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? Colors.blue[100] : Colors.white,
            foregroundColor: selected ? Colors.blue[700] : Colors.black,
            side: BorderSide(
              color: selected ? Colors.blue[700]! : Colors.grey[400]!,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(text, overflow: TextOverflow.ellipsis,style: const TextStyle(fontSize: 12),),
        ),
      ),
    );
  }

  void _addTxDialog(TransactionType type) {
    final amount = TextEditingController();
    final remark = TextEditingController();
    DateTime date = DateTime.now();
    final idGen = const Uuid();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, setSB) => Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            type == TransactionType.income
                                ? 'Cash In'
                                : 'Cash Out',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) setSB(() => date = picked);
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(date),
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Select Date',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remark,
                        decoration: const InputDecoration(labelText: 'Remark'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final a = double.tryParse(amount.text);
                            if (a == null || a <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount.'),
                                ),
                              );
                              return;
                            }
                            final tx = Transaction(
                              id: idGen.v4(),
                              description:
                                  remark.text.isEmpty
                                      ? (type == TransactionType.income
                                          ? 'Income'
                                          : 'Expense')
                                      : remark.text,
                              amount: a,
                              date: date,
                              type: type,
                            );
                            await widget.onAddTransaction(tx);
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    ).whenComplete(() => setState(() {}));
  }

  void _editTx(Transaction t) {
    final amount = TextEditingController(text: t.amount.toString());
    final remark = TextEditingController(text: t.description);
    DateTime date = t.date;
    TransactionType type = t.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, setSB) => Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Transaction',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) setSB(() => date = picked);
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(date),
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Select Date',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remark,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          RadioListTile<TransactionType>(
                            title: const Text('Income'),
                            value: TransactionType.income,
                            groupValue: type,
                            onChanged: (v) => setSB(() => type = v!),
                          ),
                          RadioListTile<TransactionType>(
                            title: const Text('Expense'),
                            value: TransactionType.expense,
                            groupValue: type,
                            onChanged: (v) => setSB(() => type = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final a = double.tryParse(amount.text);
                            if (a == null || a <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount.'),
                                ),
                              );
                              return;
                            }
                            final updated = Transaction(
                              id: t.id,
                              description:
                                  remark.text.isEmpty
                                      ? (type == TransactionType.income
                                          ? 'Income'
                                          : 'Expense')
                                      : remark.text,
                              amount: a,
                              date: date,
                              type: type,
                            );
                            await widget.onUpdateTransaction(updated);
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    ).whenComplete(() => setState(() {}));
  }
}
