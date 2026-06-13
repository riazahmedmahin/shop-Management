import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';
import '../../models/cashbook.dart';
import 'cashbooks_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'book_details_screen.dart';

class CashbookAppWrapper extends StatefulWidget {
  const CashbookAppWrapper({super.key});
  @override
  State<CashbookAppWrapper> createState() => _CashbookAppWrapperState();
}

class _CashbookAppWrapperState extends State<CashbookAppWrapper> {
  int _tab = 0;
  final List<Cashbook> _cashbooks = [];
  Cashbook? _current;
  String? _activeBusinessId;
  String _activeBusinessName = 'My Business';
  String _activeBusinessType = '';
  String _activeBusinessCategory = '';

  @override
  void initState() {
    super.initState();
    _loadActiveBusinessId();
    // Listen for auth state changes (when user metadata updates)
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      // When auth state changes (user updated), reload active business
      _loadActiveBusinessId();
    });
  }

  Future<void> _loadActiveBusinessId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      final businessId = user.userMetadata!['active_business_id'] as String?;
      final metadata = user.userMetadata!;

      // Only reload if business ID changed
      if (businessId != _activeBusinessId) {
        setState(() {
          _activeBusinessId = businessId;
          _activeBusinessName = metadata['business_name'] ?? 'My Business';
          _activeBusinessType = metadata['business_type'] ?? '';
          _activeBusinessCategory = metadata['business_category'] ?? '';
          _current = null; // Reset current book when switching business
        });
        await _loadBooksFromDatabase();
      } else {
        // Update business details even if ID didn't change (metadata might have been edited)
        setState(() {
          _activeBusinessName = metadata['business_name'] ?? 'My Business';
          _activeBusinessType = metadata['business_type'] ?? '';
          _activeBusinessCategory = metadata['business_category'] ?? '';
        });
      }
    }
  }

  Future<void> _loadBooksFromDatabase() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Load cashbooks - filter by active business if set
      var query = Supabase.instance.client
          .from('cashbooks')
          .select()
          .eq('user_id', userId);

      // Add business_id filter if active business is set
      if (_activeBusinessId != null) {
        query = query.eq('business_id', _activeBusinessId!);
      }

      final booksData = await query.order('created_at', ascending: false);

      final List<Cashbook> loadedBooks = [];

      // Batch-load transactions for all books to avoid sequential network waits
      final bookIds =
          (booksData as List).map((b) => b['id'] as String).toList();
      List txData = [];
      if (bookIds.isNotEmpty) {
        // Build an OR query for PostgREST when `in_` helper isn't available.
        final orQuery = bookIds.map((id) => 'cashbook_id.eq.$id').join(',');
        txData = await Supabase.instance.client
            .from('transactions')
            .select()
            .or(orQuery)
            .order('date', ascending: false);
      }

      // Group transactions by cashbook_id
      final Map<String, List<Map<String, dynamic>>> txByBook = {};
      for (var tx in txData) {
        final cid = tx['cashbook_id'] as String;
        txByBook.putIfAbsent(cid, () => []).add(Map<String, dynamic>.from(tx));
      }

      for (var bookData in (booksData as List)) {
        final bookId = bookData['id'] as String;
        final txsForBook = txByBook[bookId] ?? [];
        final transactions =
            txsForBook
                .map(
                  (tx) => Transaction(
                    id: tx['id'],
                    description: tx['description'] ?? '',
                    amount: (tx['amount'] as num).toDouble(),
                    date: DateTime.parse(tx['date']),
                    type:
                        tx['type'] == 'income'
                            ? TransactionType.income
                            : TransactionType.expense,
                  ),
                )
                .toList();

        final book = Cashbook(
          id: bookId,
          name: bookData['name'] ?? '',
          createdAt: DateTime.parse(bookData['created_at']),
          transactions: transactions,
        );
        loadedBooks.add(book);
      }

      setState(() {
        _cashbooks.clear();
        _cashbooks.addAll(loadedBooks);
        if (_cashbooks.isNotEmpty && _current == null) {
          _current = _cashbooks.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
      }
    }
  }

  Future<void> _addBook(String name) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response =
          await Supabase.instance.client.from('cashbooks').insert({
            'user_id': userId,
            'name': name,
            'business_id': _activeBusinessId,
            'created_at': DateTime.now().toIso8601String(),
          }).select();

      if (response.isNotEmpty) {
        final newBook = Cashbook(
          id: response[0]['id'],
          name: name,
          createdAt: DateTime.now(),
        );
        setState(() {
          _cashbooks.add(newBook);
          _current = newBook;
          _tab = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cashbook created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating book: $e')));
      }
    }
  }

  Future<void> _renameBook(String id, String name) async {
    try {
      await Supabase.instance.client
          .from('cashbooks')
          .update({
            'name': name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      setState(() {
        final i = _cashbooks.indexWhere((b) => b.id == id);
        if (i != -1) _cashbooks[i].name = name;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cashbook renamed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error renaming book: $e')));
      }
    }
  }

  Future<void> _deleteBook(String id) async {
    try {
      await Supabase.instance.client.from('cashbooks').delete().eq('id', id);

      setState(() {
        _cashbooks.removeWhere((b) => b.id == id);
        if (_current?.id == id) {
          _current = _cashbooks.isNotEmpty ? _cashbooks.first : null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cashbook deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting book: $e')));
      }
    }
  }

  void _openBook(Cashbook b) {
    setState(() => _current = b);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => BookDetailsScreen(
              cashbook: b,
              onAddTransaction: _addTx,
              onUpdateTransaction: _updateTx,
              onDeleteTransactions: _deleteTxs,
            ),
      ),
    ).then((_) {
      // Refresh book when coming back
      _loadBooksFromDatabase();
    });
  }

  Future<void> _addTx(Transaction t) async {
    try {
      final response =
          await Supabase.instance.client.from('transactions').insert({
            'cashbook_id': _current!.id,
            'description': t.description,
            'amount': t.amount,
            'type': t.type == TransactionType.income ? 'income' : 'expense',
            'date': t.date.toIso8601String(),
          }).select();

      if (response.isNotEmpty) {
        final dbId = response[0]['id'];
        final newTx = Transaction(
          id: dbId,
          description: t.description,
          amount: t.amount,
          date: t.date,
          type: t.type,
        );
        setState(() {
          _current?.transactions.add(newTx);
          _current?.transactions.sort((a, b) => b.date.compareTo(a.date));
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction added successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding transaction: $e')));
      }
    }
  }

  Future<void> _updateTx(Transaction t) async {
    try {
      await Supabase.instance.client
          .from('transactions')
          .update({
            'description': t.description,
            'amount': t.amount,
            'type': t.type == TransactionType.income ? 'income' : 'expense',
            'date': t.date.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', t.id);

      setState(() {
        final idx =
            _current?.transactions.indexWhere((x) => x.id == t.id) ?? -1;
        if (idx != -1) {
          _current!.transactions[idx] = t;
          _current!.transactions.sort((a, b) => b.date.compareTo(a.date));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating transaction: $e')),
        );
      }
    }
  }

  Future<void> _deleteTxs(List<String> ids) async {
    try {
      if (ids.isNotEmpty) {
        final orQuery = ids.map((id) => 'id.eq.$id').join(',');
        await Supabase.instance.client
            .from('transactions')
            .delete()
            .or(orQuery);
      }

      setState(() {
        _current?.transactions.removeWhere((t) => ids.contains(t.id));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting transactions: $e')),
        );
      }
    }
  }

  Future<void> _showSwitchBusinessDialog() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch all businesses for this user
      final businesses = await Supabase.instance.client
          .from('businesses')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (businesses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No businesses found. Create one first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Show dialog with business list
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Switch Business'),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    final isActive = _activeBusinessId == business['id'];

                    return GestureDetector(
                      onTap: isActive
                          ? null
                          : () async {
                              try {
                                // Update active business
                                await Supabase.instance.client.auth
                                    .updateUser(
                                      UserAttributes(
                                        data: {
                                          'active_business_id': business['id'],
                                          'business_name': business['name'],
                                          'business_type': business['type'],
                                          'business_category':
                                              business['category'],
                                        },
                                      ),
                                    );

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Switched to ${business['name']}',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error switching business: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blue[50] : Colors.grey[50],
                          border: Border.all(
                            color: isActive
                                ? Colors.blue[600]!
                                : Colors.grey[300]!,
                            width: isActive ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business_center,
                                    size: 32,
                                    color: isActive
                                        ? Colors.blue[600]
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    business['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      color: isActive
                                          ? Colors.blue[600]
                                          : Colors.grey[900],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${business['type']}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    business['category'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading businesses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          CashbooksScreen(
            cashbooks: _cashbooks,
            onAddCashbook: _addBook,
            onRenameCashbook: _renameBook,
            onDeleteCashbook: _deleteBook,
            onViewBookDetails: _openBook,
            activeBusinessId: _activeBusinessId,
            activeBusinessName: _activeBusinessName,
            activeBusinessType: _activeBusinessType,
            activeBusinessCategory: _activeBusinessCategory,
            onSwitchBusiness: _showSwitchBusinessDialog,
          ),
          AnalyticsScreen(cashbooks: _cashbooks),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Cashbooks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
