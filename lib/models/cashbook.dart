import 'transaction.dart';

class Cashbook {
  final String id;
  String name;
  final DateTime createdAt;
  List<Transaction> transactions;

  Cashbook({
    required this.id,
    required this.name,
    required this.createdAt,
    List<Transaction>? transactions,
  }) : transactions = transactions ?? [];

  double get totalCashIn => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalCashOut => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get netBalance => totalCashIn - totalCashOut;

  DateTime get lastUpdated {
    if (transactions.isEmpty) return createdAt;
    final latestTx = transactions.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    return latestTx.date;
  }
}
