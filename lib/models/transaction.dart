enum TransactionType { income, expense }

class Transaction {
  final String id;
  String description;
  double amount;
  DateTime date;
  TransactionType type;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
  });
}
