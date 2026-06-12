import 'package:flutter/material.dart';
import '../../models/cashbook.dart';

class SearchBooksPage extends StatefulWidget {
  final List<Cashbook> allBooks;
  final Function(Cashbook) onBookChosen;
  const SearchBooksPage({
    super.key,
    required this.allBooks,
    required this.onBookChosen,
  });
  @override
  State<SearchBooksPage> createState() => _SearchBooksPageState();
}

class _SearchBooksPageState extends State<SearchBooksPage> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final results =
        widget.allBooks
            .where((b) => b.name.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search books...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v),
          onSubmitted: (v) => setState(() => _q = v),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _q = ''),
          ),
        ],
      ),
      body:
          results.isEmpty
              ? const Center(child: Text('No books found'))
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final b = results[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onBookChosen(b);
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.book_outlined,
                            size: 40,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              b.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '৳ ${b.netBalance.toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
