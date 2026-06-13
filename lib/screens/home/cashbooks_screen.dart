import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cashbook.dart';
import 'search_books_page.dart';
import 'subscription_screen.dart';

enum SortOption { lastUpdated, nameAZ, netHighLow, netLowHigh, lastCreated }

class CashbooksScreen extends StatefulWidget {
  final List<Cashbook> cashbooks;
  final Function(String) onAddCashbook;
  final Function(String, String) onRenameCashbook;
  final Function(String) onDeleteCashbook;
  final Function(Cashbook) onViewBookDetails;
  final String? activeBusinessId;
  final String activeBusinessName;
  final String activeBusinessType;
  final String activeBusinessCategory;
  final VoidCallback? onSwitchBusiness;

  const CashbooksScreen({
    super.key,
    required this.cashbooks,
    required this.onAddCashbook,
    required this.onRenameCashbook,
    required this.onDeleteCashbook,
    required this.onViewBookDetails,
    this.activeBusinessId,
    this.activeBusinessName = 'My Business',
    this.activeBusinessType = '',
    this.activeBusinessCategory = '',
    this.onSwitchBusiness,
  });

  @override
  State<CashbooksScreen> createState() => _CashbooksScreenState();
}

class _CashbooksScreenState extends State<CashbooksScreen> {
  final PageController _banner = PageController();
  SortOption _sort = SortOption.lastUpdated;

  List<Cashbook> get _sortedBooks {
    final list = [...widget.cashbooks];
    switch (_sort) {
      case SortOption.lastUpdated:
        list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case SortOption.nameAZ:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortOption.netHighLow:
        list.sort((a, b) => b.netBalance.compareTo(a.netBalance));
        break;
      case SortOption.netLowHigh:
        list.sort((a, b) => a.netBalance.compareTo(b.netBalance));
        break;
      case SortOption.lastCreated:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  void _showAddBookDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Add New Cashbook'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(labelText: 'Cashbook Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (c.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name.')),
                    );
                    return;
                  }
                  widget.onAddCashbook(c.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showRenameBookDialog(Cashbook b) {
    final c = TextEditingController(text: b.name);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Rename Cashbook'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(labelText: 'New Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (c.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name.')),
                    );
                    return;
                  }
                  widget.onRenameCashbook(b.id, c.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Change'),
              ),
            ],
          ),
    );
  }

  void _showDeleteBookDialog(Cashbook b) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Cashbook'),
            content: Text(
              'Are you sure you want to delete "${b.name}" cashbook?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  widget.onDeleteCashbook(b.id);
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, setSB) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RadioListTile<SortOption>(
                        title: const Text('Last update'),
                        value: SortOption.lastUpdated,
                        groupValue: _sort,
                        onChanged: (v) => setSB(() => _sort = v!),
                      ),
                      RadioListTile<SortOption>(
                        title: const Text('Name (A to Z)'),
                        value: SortOption.nameAZ,
                        groupValue: _sort,
                        onChanged: (v) => setSB(() => _sort = v!),
                      ),
                      RadioListTile<SortOption>(
                        title: const Text('Net balance (High to Low)'),
                        value: SortOption.netHighLow,
                        groupValue: _sort,
                        onChanged: (v) => setSB(() => _sort = v!),
                      ),
                      RadioListTile<SortOption>(
                        title: const Text('Net balance (Low to High)'),
                        value: SortOption.netLowHigh,
                        groupValue: _sort,
                        onChanged: (v) => setSB(() => _sort = v!),
                      ),
                      RadioListTile<SortOption>(
                        title: const Text('Last created'),
                        value: SortOption.lastCreated,
                        groupValue: _sort,
                        onChanged: (v) => setSB(() => _sort = v!),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Apply',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = _sortedBooks;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.onSwitchBusiness,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activeBusinessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.activeBusinessType}${widget.activeBusinessCategory.isNotEmpty ? ' • ${widget.activeBusinessCategory}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Swipeable banners
          SizedBox(
            height: 178,
            child: PageView(
              controller: _banner,
              children: [
                _bannerCard(
                  context,
                  title: 'CashBook is Going Premium!',
                  subtitle: 'Please subscribe to continue using CashBook.',
                  color: Colors.blue[700]!,
                ),
                _bannerCard(
                  context,
                  title: 'Basic Learning',
                  subtitle: 'Know more about CashBook features.',
                  color: Colors.orange[700]!,
                ),
                _bannerCard(
                  context,
                  title: 'New Features Coming!',
                  subtitle: 'Stay tuned for exciting updates.',
                  color: Colors.purple[700]!,
                ),
              ],
            ),
          ),
          // "Your Books" row with Search + Filter moved here
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Your Books',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '${books.length} total',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search books',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => SearchBooksPage(
                              allBooks: widget.cashbooks,
                              onBookChosen: (b) => widget.onViewBookDetails(b),
                            ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Sort',
                  onPressed: _openSortSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child:
                books.isEmpty
                    ? _EmptyBooksView(onAddFirstBook: _showAddBookDialog)
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: books.length,
                      itemBuilder: (_, i) {
                        final b = books[i];
                        return GestureDetector(
                          onTap: () => widget.onViewBookDetails(b),
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder:
                                  (_) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text('Rename'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showRenameBookDialog(b);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showDeleteBookDialog(b);
                                        },
                                      ),
                                    ],
                                  ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.book_outlined,
                                      size: 28,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Last updated: ${DateFormat('dd MMM yyyy').format(b.lastUpdated)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '৳ ${b.netBalance.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  b.netBalance >= 0
                                                      ? Colors.green[700]
                                                      : Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.grey,
                                          size: 22,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: const ButtonStyle(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'rename') {
                                            _showRenameBookDialog(b);
                                          } else if (value == 'delete') {
                                            _showDeleteBookDialog(b);
                                          }
                                        },
                                        itemBuilder:
                                            (context) => [
                                              const PopupMenuItem(
                                                value: 'rename',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 20),
                                                    SizedBox(width: 8),
                                                    Text('Rename'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookDialog,
        icon: const Icon(Icons.add),
        label: const Text('ADD NEW'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _bannerCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(100, 36),
                      ),
                      child: const Text('Subscribe'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBooksView extends StatelessWidget {
  final VoidCallback onAddFirstBook;
  const _EmptyBooksView({required this.onAddFirstBook});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Icon(Icons.menu_book, size: 80, color: Colors.blue[600]),
            const SizedBox(height: 16),
            const Text(
              'Add your first book to get started',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Setup your business by adding ‘new books’ and ‘team members’',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.book),
                label: const Text('ADD FIRST BOOK'),
                onPressed: onAddFirstBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
