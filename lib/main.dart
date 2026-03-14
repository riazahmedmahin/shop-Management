import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wkmrbwfzxlbapqqragzb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbXJid2Z6eGxiYXBxcXJhZ3piIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxNTgzNDQsImV4cCI6MjA3OTczNDM0NH0.sC1YOmqtya4P8RTeAZi8PGnJaP81c_Fn8rYSczuTn0M',
  );

  runApp(const MyApp());
}
// ---------------- Models ----------------

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

class FAQItem {
  final String title;
  final String content;
  final String category;

  FAQItem({required this.title, required this.content, required this.category});
}

class BusinessSetupData {
  String? name;
  String? category;
  String? type;
  String? businessType; // New field

  BusinessSetupData({this.name, this.category, this.type, this.businessType});
}

// Helper used with compute() to build PDF bytes off the UI thread.
Future<Uint8List> _buildPdfBytes(Map<String, dynamic> payload) async {
  final name = payload['name'] as String? ?? '';
  final dateFilter = payload['dateFilter'] as String? ?? 'All';
  final startIso = payload['start'] as String?;
  final endIso = payload['end'] as String?;
  final txs = (payload['txs'] as List).cast<Map<String, dynamic>>();

  final pdf = pw.Document();

  final totalIn = txs
      .where((t) => t['type'] == 'income')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
  final totalOut = txs
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Cashbook Report: $name',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Date Range: $dateFilter'),
              if (dateFilter == 'Custom' && startIso != null && endIso != null)
                pw.Text('From: ${startIso}  To: ${endIso}'),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Description', 'Amount', 'Type'],
                data:
                    txs
                        .map(
                          (t) => [
                            t['date'].toString(),
                            t['description'].toString(),
                            '৳ ${(t['amount'] as num).toDouble().toStringAsFixed(2)}',
                            t['type'] == 'income' ? 'Income' : 'Expense',
                          ],
                        )
                        .toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellPadding: const pw.EdgeInsets.all(5),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Total Cash In:  ${totalIn.toStringAsFixed(2)}'),
              pw.Text('Total Cash Out:  ${totalOut.toStringAsFixed(2)}'),
              pw.Text(
                'Net Balance:  ${(totalIn - totalOut).toStringAsFixed(2)}',
              ),
            ],
          ),
    ),
  );

  final bytes = await pdf.save();
  return Uint8List.fromList(bytes);
}

// Helper used with compute() to build a CSV string off the UI thread.
String _buildCsvString(Map<String, dynamic> payload) {
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

// ---------------- App ----------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My CashBook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey, width: 2),
          ),
        ),
      ),
      home: StreamBuilder<AuthState>(
        stream: _authStateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          final session = snapshot.data?.session;
          if (session != null) {
            return const CashbookAppWrapper();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

// ---------------- Splash ----------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.currency_exchange,
                  size: 48,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'CASHBOOK',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(
                child: Icon(Icons.person, size: 80, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hello',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group),
                SizedBox(width: 5),
                Text('1 member'),
              ],
            ),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Column(
                  children: [
                    Icon(Icons.security, color: Colors.green),
                    Text('100% Safe & Secure'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.blue),
                    Text('Auto Data Backup'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Auth ----------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Retail',
    'Wholesale',
    'Service',
    'Manufacturing',
    'Technology',
    'Healthcare',
    'Education',
    'Finance',
    'Hospitality',
    'Real Estate',
    'Other',
  ];

  final List<String> _types = [
    'Sole Proprietorship',
    'Partnership',
    'Limited Liability Company (LLC)',
    'Corporation',
    'Non-profit Organization',
    'Other',
  ];

  Future<void> _showBusinessProfileDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Check if user already has business profile
    final userData = user.userMetadata;
    if (userData != null &&
        userData['business_name'] != null &&
        userData['business_category'] != null &&
        userData['business_type'] != null) {
      // User already has business profile, navigate to home
      return;
    }

    // Show dialog to collect business information
    String? businessName = userData?['business_name'];
    String? selectedCategory = userData?['business_category'];
    String? selectedType = userData?['business_type'];

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSB) => AlertDialog(
                  title: const Text('Complete Your Business Profile'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          onChanged: (v) => setSB(() => businessName = v),
                          controller: TextEditingController(
                            text: businessName ?? '',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            hintText: 'Enter your business name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          items:
                              _types
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setSB(() => selectedType = v),
                          decoration: const InputDecoration(
                            labelText: 'Business Type',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          items:
                              _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setSB(() => selectedCategory = v),
                          decoration: const InputDecoration(
                            labelText: 'Business Category',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () async {
                        if ((businessName ?? '').isEmpty ||
                            selectedCategory == null ||
                            selectedType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          final userId =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (userId == null) return;

                          // Create or update business in database
                          final existingBusiness = await Supabase
                              .instance
                              .client
                              .from('businesses')
                              .select()
                              .eq('user_id', userId)
                              .order('created_at', ascending: true)
                              .limit(1);

                          String businessId;
                          if (existingBusiness.isNotEmpty) {
                            // Update existing business
                            businessId = existingBusiness[0]['id'];
                            await Supabase.instance.client
                                .from('businesses')
                                .update({
                                  'name': businessName?.trim() ?? '',
                                  'category': selectedCategory,
                                  'type': selectedType,
                                })
                                .eq('id', businessId);
                          } else {
                            // Create new business
                            final response =
                                await Supabase.instance.client
                                    .from('businesses')
                                    .insert({
                                      'user_id': userId,
                                      'name': businessName?.trim() ?? '',
                                      'category': selectedCategory,
                                      'type': selectedType,
                                    })
                                    .select();

                            if (response.isNotEmpty) {
                              businessId = response[0]['id'];
                            } else {
                              throw Exception('Failed to create business');
                            }
                          }

                          // Update user metadata with business profile and active_business_id
                          await Supabase.instance.client.auth.updateUser(
                            UserAttributes(
                              data: {
                                'business_name': businessName?.trim() ?? '',
                                'business_category': selectedCategory,
                                'business_type': selectedType,
                                'active_business_id': businessId,
                              },
                            ),
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Business profile saved successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error saving profile: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        // Show business profile dialog if not already set
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _showBusinessProfileDialog();
        }
        // Do NOT navigate here; the auth stream in MyApp will switch the UI.
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.currency_exchange,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CASHBOOK',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart accounting system for your business',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Welcome Text
                  const Text(
                    'Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.email, color: Colors.blue[600]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue[600]!,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Password Field
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.lock, color: Colors.blue[600]),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue[600]!,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [

                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password recovery feature coming soon',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sign Up Link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        children: [
                          TextSpan(text: 'Don\'t have an account? '),
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _businessName = TextEditingController();
  String? _selectedCategory;
  String? _selectedType;
  bool _agreeTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Retail',
    'Wholesale',
    'Service',
    'Manufacturing',
    'Technology',
    'Healthcare',
    'Education',
    'Finance',
    'Hospitality',
    'Real Estate',
    'Other',
  ];

  final List<String> _types = [
    'Sole Proprietorship',
    'Partnership',
    'Limited Liability Company (LLC)',
    'Corporation',
    'Non-profit Organization',
    'Other',
  ];

  Future<void> _signup() async {
    if (_fullName.text.isEmpty ||
        _email.text.isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty ||
        _businessName.text.isEmpty ||
        _selectedCategory == null ||
        _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'full_name': _fullName.text.trim(),
          'business_name': _businessName.text.trim(),
          'business_category': _selectedCategory,
          'business_type': _selectedType,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Create business entry in database
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final response =
              await Supabase.instance.client.from('businesses').insert({
                'user_id': user.id,
                'name': _businessName.text.trim(),
                'category': _selectedCategory,
                'type': _selectedType,
              }).select();

          if (response.isNotEmpty) {
            final businessId = response[0]['id'];
            // Update user metadata with active_business_id
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'active_business_id': businessId}),
            );
          }
        } catch (e) {
          // Log error but continue - signup already succeeded
          print('Error creating business: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign up successful! Please login now.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                const Text(
                  'Create a New Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start managing your business',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // Full Name Field
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullName,
                  keyboardType: TextInputType.name,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.person, color: Colors.blue[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Email Field
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@email.com',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.email, color: Colors.blue[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Password Field
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[600]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use at least 6 characters',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),

                // Confirm Password Field
                Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[600]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Business Name Field
                Text(
                  'Business Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _businessName,
                  decoration: InputDecoration(
                    hintText: 'Your Business Name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.business, color: Colors.blue[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Business Category Dropdown
                Text(
                  'Business Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Select a category'),
                  items:
                      _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.category, color: Colors.blue[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Business Type Dropdown
                Text(
                  'Business Type',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  hint: const Text('Select a business type'),
                  items:
                      _types
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() => _selectedType = value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.apartment, color: Colors.blue[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Terms & Conditions
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreeTerms,
                        onChanged: (value) {
                          setState(() => _agreeTerms = value ?? false);
                        },
                        activeColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ''),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 20),

                // Sign In Link
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pop(context);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }
}

// S11: Add Business Name
class BusinessNameStep extends StatefulWidget {
  final BusinessSetupData setup;
  const BusinessNameStep({super.key, required this.setup});

  @override
  State<BusinessNameStep> createState() => _BusinessNameStepState();
}

class _BusinessNameStepState extends State<BusinessNameStep> {
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.setup.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _name.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Business Name'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Business Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Business Name',
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomProgressBar(
                stepText: 'Business Setup: Step 1/3',
                primaryText: 'NEXT',
                primaryEnabled: canNext,
                onPrimary: () {
                  widget.setup.name = _name.text.trim();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessCategoryStep(setup: widget.setup),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// S12: Select Business Category
class BusinessCategoryStep extends StatefulWidget {
  final BusinessSetupData setup;
  const BusinessCategoryStep({super.key, required this.setup});

  @override
  State<BusinessCategoryStep> createState() => _BusinessCategoryStepState();
}

class _BusinessCategoryStepState extends State<BusinessCategoryStep> {
  final List<_Category> _cats = const [
    _Category('Agriculture', Icons.agriculture),
    _Category('Construction', Icons.foundation),
    _Category('Education', Icons.menu_book),
    _Category('Electronics', Icons.electrical_services),
    _Category('Financial Services', Icons.payments),
    _Category('Food/Restaurant', Icons.restaurant),
    _Category('Clothes/Fashion', Icons.checkroom),
    _Category('Hardware', Icons.handyman),
    _Category('Jewellery', Icons.diamond),
    _Category('Healthcare & Fitness', Icons.local_hospital),
    _Category('Kirana/Grocery', Icons.local_grocery_store),
    _Category('Transport', Icons.local_shipping),
  ];

  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.setup.category;
  }

  @override
  Widget build(BuildContext context) {
    final canNext = selected != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business Category'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessTypeStep(setup: widget.setup),
                ),
              );
            },
            child: const Text('SKIP', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will help us personalise your app experience',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 2.6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children:
                          _cats.map((c) {
                            final isSel = selected == c.name;
                            return InkWell(
                              onTap: () => setState(() => selected = c.name),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSel ? Colors.blue[50] : Colors.white,
                                  border: Border.all(
                                    color:
                                        isSel
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                    width: isSel ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      c.icon,
                                      color: isSel ? Colors.blue : Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isSel)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomProgressBar(
                stepText: 'Business Setup: Step 2/3',
                primaryText: 'NEXT',
                primaryEnabled: canNext,
                onPrimary: () {
                  widget.setup.category = selected;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessTypeStep(setup: widget.setup),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Category {
  final String name;
  final IconData icon;
  const _Category(this.name, this.icon);
}

// S13: Select Business Type
class BusinessTypeStep extends StatefulWidget {
  final BusinessSetupData setup;
  const BusinessTypeStep({super.key, required this.setup});

  @override
  State<BusinessTypeStep> createState() => _BusinessTypeStepState();
}

class _BusinessTypeStepState extends State<BusinessTypeStep> {
  final List<String> _types = const [
    'Retailer',
    'Distributor',
    'Manufacturer',
    'Service Provider',
    'Trader',
    'Other',
  ];
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.setup.type ?? 'Retailer';
  }

  void _finish() {
    widget.setup.type = selected;
    // After completing setup, go to the main app
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CashbookAppWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDone = selected != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business Type'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('SKIP', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will help us personalise your app experience',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _types.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final t = _types[i];
                        final isSel = selected == t;
                        return InkWell(
                          onTap: () => setState(() => selected = t),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel ? Colors.blue[50] : Colors.white,
                              border: Border.all(
                                color:
                                    isSel ? Colors.blue : Colors.grey.shade300,
                                width: isSel ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _typeIcon(t),
                                  color: isSel ? Colors.blue : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isSel)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.blue,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomProgressBar(
                stepText: 'Business Setup: Step 3/3',
                primaryText: 'DONE',
                primaryEnabled: canDone,
                onPrimary: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'Retailer':
        return Icons.storefront;
      case 'Distributor':
        return Icons.local_shipping;
      case 'Manufacturer':
        return Icons.factory;
      case 'Service Provider':
        return Icons.home_repair_service;
      case 'Trader':
        return Icons.trending_up;
      default:
        return Icons.widgets;
    }
  }
}

class _BottomProgressBar extends StatelessWidget {
  final String stepText;
  final String primaryText;
  final bool primaryEnabled;
  final VoidCallback onPrimary;

  const _BottomProgressBar({
    required this.stepText,
    required this.primaryText,
    required this.primaryEnabled,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      //color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    children: [
                      const TextSpan(text: 'Business Setup: '),
                      TextSpan(
                        text: stepText.split(':').last.trim(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: primaryEnabled ? onPrimary : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- App Wrapper (state) ----------------

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
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    final isActive = _activeBusinessId == business['id'];

                    return Card(
                      color: isActive ? Colors.blue[50] : null,
                      child: ListTile(
                        title: Text(
                          business['name'],
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? Colors.blue : null,
                          ),
                        ),
                        subtitle: Text(
                          '${business['type']} • ${business['category']}',
                        ),
                        // trailing:
                        //     isActive
                        //         ? const Icon(
                        //           Icons.check_circle,
                        //           color: Colors.blue,
                        //         )
                        //         : null,
                        onTap:
                            isActive
                                ? null
                                : () async {
                                  try {
                                    // Update active business
                                    await Supabase.instance.client.auth
                                        .updateUser(
                                          UserAttributes(
                                            data: {
                                              'active_business_id':
                                                  business['id'],
                                              'business_name': business['name'],
                                              'business_type': business['type'],
                                              'business_category':
                                                  business['category'],
                                            },
                                          ),
                                        );

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
          const AnalyticsScreen(),
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

// ---------------- Cashbooks Screen ----------------

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
                  backgroundColor: Colors.blue, // বোতামের ব্যাকগ্রাউন্ড রঙ
                  foregroundColor: Colors.white, // টেক্সট রঙ
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
        // Moved search and filter away from AppBar as requested.
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
                      itemCount: books.length,
                      itemBuilder: (_, i) {
                        final b = books[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.book_outlined,
                              color: Colors.blueAccent,
                            ),
                            title: Text(b.name),
                            subtitle: Text(
                              'Created ${DateFormat('dd MMM yyyy').format(b.createdAt)} • Net ৳ ${b.netBalance.toStringAsFixed(2)}',
                            ),
                            onTap: () => widget.onViewBookDetails(b),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'rename') _showRenameBookDialog(b);
                                if (v == 'delete') _showDeleteBookDialog(b);
                              },
                              itemBuilder:
                                  (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Rename'),
                                      ),
                                    ),

                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete),
                                        title: Text('Delete Book'),
                                      ),
                                    ),
                                  ],
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

// S14-like empty state
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

// ---------------- Search Books Page (dedicated) ----------------

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
              : ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final b = results[i];
                  return ListTile(
                    leading: const Icon(Icons.book_outlined),
                    title: Text(b.name),
                    subtitle: Text('Net ৳ ${b.netBalance.toStringAsFixed(2)}'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onBookChosen(b);
                    },
                  );
                },
              ),
    );
  }
}

// ---------------- Book Details (transactions, filters, PDF) ----------------

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

      final bytes = await compute(_buildPdfBytes, payload);

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

      final csv = await compute(_buildCsvString, payload);

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
                  // PopupMenuButton<String>(
                  //   onSelected:
                  //       (v) => ScaffoldMessenger.of(
                  //         context,
                  //       ).showSnackBar(SnackBar(content: Text('Selected: $v'))),
                  //   itemBuilder:
                  //       (_) => const [
                  //         PopupMenuItem(
                  //           value: 'settings',
                  //           child: Text('Book Settings'),
                  //         ),
                  //         PopupMenuItem(
                  //           value: 'share',
                  //           child: Text('Share Book'),
                  //         ),
                  //       ],
                  // ),
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
          child: Text(text, overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 12),),
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

// ---------------- Analytics Screen ----------------

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business Analytics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Income',
                          value: '৳ 15,000',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Total Expense',
                          value: '৳ 5,500',
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
                          value: '৳ 9,500',
                          icon: Icons.account_balance,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Transactions',
                          value: '23',
                          icon: Icons.receipt_long,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Reports Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _ReportTile(
                    title: 'Daily Report',
                    subtitle: 'View today\'s transactions',
                    icon: Icons.calendar_today,
                    onTap:
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily report feature')),
                        ),
                  ),
                  _ReportTile(
                    title: 'Monthly Report',
                    subtitle: 'Analyze monthly trends',
                    icon: Icons.calendar_month,
                    onTap:
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Monthly report feature'),
                          ),
                        ),
                  ),
                  _ReportTile(
                    title: 'Yearly Report',
                    subtitle: 'Year-on-year analysis',
                    icon: Icons.date_range,
                    onTap:
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Yearly report feature'),
                          ),
                        ),
                  ),
                  _ReportTile(
                    title: 'Category Breakdown',
                    subtitle: 'Income & expense by category',
                    icon: Icons.pie_chart,
                    onTap:
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Category breakdown feature'),
                          ),
                        ),
                  ),
                ],
              ),
            ),
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
                      label: const Text('Export as PDF'),
                      onPressed:
                          () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting PDF...')),
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export as Excel'),
                      onPressed:
                          () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting Excel...')),
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

// ---------------- Help & Support ----------------

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<FAQItem> all = [
    FAQItem(
      title: 'How to use CashBook App?',
      content: 'Detailed steps on using the app...',
      category: 'Basics',
    ),
    FAQItem(
      title: 'What is Business Profile?',
      content: 'Explanation of business profile features...',
      category: 'Business Profile',
    ),
    FAQItem(
      title: 'How to do backdated entries?',
      content: 'Steps to add entries for past dates...',
      category: 'Basics',
    ),
    FAQItem(
      title: 'How to view daily or monthly data in a book?',
      content: 'Instructions for viewing reports...',
      category: 'Basics',
    ),
    FAQItem(
      title: 'How to Change Mobile Number?',
      content: 'Steps to update your mobile number...',
      category: 'Basics',
    ),
    FAQItem(
      title: 'How to setup App Lock with Fingerprint/Pin/Password?',
      content: 'Security setup guide...',
      category: 'Basics',
    ),
  ];

  String _q = '';
  String _cat = 'All';

  List<FAQItem> get filtered {
    var f =
        all.where((faq) {
          if (_q.isEmpty) return true;
          final x = _q.toLowerCase();
          return faq.title.toLowerCase().contains(x) ||
              faq.content.toLowerCase().contains(x);
        }).toList();
    if (_cat != 'All') {
      f = f.where((faq) => faq.category == _cat).toList();
    }
    return f;
  }

  List<String> get cats {
    final s = all.map((f) => f.category).toSet().toList()..sort();
    return ['All', ...s];
  }

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'example@gmail.com',
      queryParameters: {
        'subject': 'Cashbook Support',
        'body': 'Hello Support,\n\nI need help with ...',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    final native = Uri.parse('whatsapp://send?text=Hello%20Cashbook%20Support');
    final web = Uri.parse('https://wa.me/?text=Hello%20Cashbook%20Support');
    if (await canLaunchUrl(native)) {
      await launchUrl(native);
    } else if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WhatsApp not available')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support'), centerTitle: true),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Frequently asked questions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _faqCard(
                      context,
                      'FAQ- English-V-3.0.0-Ho',
                      'How to use CashBook App?',
                      // Note: If you embed images, use the provided Source URL in your app’s assets/network widget
                      'https://hebbkx1anhila5yf.public.blob.vercel-storage.com/s3-hKVvl6mr38LCrdpW6a88dSsNlY8MXD.jpeg',
                    ),
                    _faqCard(
                      context,
                      'FAQ- Business Profile',
                      'What is Business Profile?',
                      'https://hebbkx1anhila5yf.public.blob.vercel-storage.com/s3-hKVvl6mr38LCrdpW6a88dSsNlY8MXD.jpeg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: cats.map((c) => _catChip(c)).toList()),
                ),
              ),
              Expanded(
                child:
                    list.isEmpty
                        ? const Center(
                          child: Text(
                            'No FAQs found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final f = list[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 0.5,
                              child: ListTile(
                                title: Text(f.title),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap:
                                    () => ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(content: Text(f.content)),
                                    ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'emailFab',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700],
                  onPressed: _sendEmail,
                  child: const Icon(Icons.mail_outline),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'waFab',
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  onPressed: _openWhatsApp,
                  child: const Icon(Icons.wechat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqCard(BuildContext context, String title, String sub, String url) {
    return Card(
      margin: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              url,
              height: 100,
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 100,
                  width: 200,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.broken_image)),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String text) {
    final selected = _cat == text;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(text),
        selected: selected,
        onSelected: (s) => setState(() => _cat = text),
        selectedColor: Colors.blue[100],
        backgroundColor: Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.blue[700] : Colors.black,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? Colors.blue[700]! : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

// ---------------- Settings / Profile ----------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Sample business data (in real app, this would come from state management)
  late String businessName;
  late String businessType;
  late String businessCategory;

  // User profile data
  late String fullName;
  late String userEmail;
  late String phone;

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
    _loadUserProfile();
  }

  void _loadBusinessProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      final metadata = user.userMetadata!;
      businessName = metadata['business_name'] ?? 'My Business';
      businessType = metadata['business_type'] ?? 'Retailer';
      businessCategory = metadata['business_category'] ?? 'Electronics';
    } else {
      businessName = 'My Business';
      businessType = 'Retailer';
      businessCategory = 'Electronics';
    }
    setState(() {});
  }

  void _loadUserProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      fullName = user.userMetadata?['full_name'] ?? 'User';
      userEmail = user.email ?? 'Not set';
      phone = user.userMetadata?['phone'] ?? 'Not set';
    } else {
      fullName = 'User';
      userEmail = 'Not set';
      phone = 'Not set';
    }
    setState(() {});
  }

  void _editUserProfile() {
    final nameController = TextEditingController(text: fullName);
    final emailController = TextEditingController(text: userEmail);
    final phoneController = TextEditingController(text: phone);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Your Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full Name Field
                  Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your full name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Your email (cannot be changed)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter your mobile number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            nameController.dispose();
                            emailController.dispose();
                            phoneController.dispose();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final finalName = nameController.text.trim();
                            final finalPhone = phoneController.text.trim();

                            if (finalName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Name cannot be empty'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            try {
                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) {
                                throw Exception('User not found');
                              }

                              // Update user metadata
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(
                                  data: {
                                    'full_name': finalName,
                                    'phone': finalPhone,
                                  },
                                ),
                              );

                              if (mounted) {
                                setState(() {
                                  fullName = finalName;
                                  phone = finalPhone;
                                });

                                nameController.dispose();
                                emailController.dispose();
                                phoneController.dispose();
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Profile updated successfully'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editBusinessProfile() {
    final businessTypeOptions = [
      'Sole Proprietorship',
      'Partnership',
      'Limited Liability Company (LLC)',
      'Corporation',
      'Non-profit Organization',
      'Retailer',
      'Distributor',
      'Manufacturer',
      'Service Provider',
      'Trader',
      'Other',
    ];

    final businessCategoryOptions = [
      'Agriculture',
      'Construction',
      'Education',
      'Electronics',
      'Financial Services',
      'Food/Restaurant',
      'Clothes/Fashion',
      'Hardware',
      'Jewellery',
      'Healthcare & Fitness',
      'Kirana/Grocery',
      'Transport',
      'Retail',
      'Wholesale',
      'Service',
      'Manufacturing',
      'Technology',
      'Hospitality',
      'Real Estate',
      'Other',
    ];

    // Map old category values to new ones for backward compatibility
    final categoryMap = {
      'Healthcare': 'Healthcare & Fitness',
      'Healthcare & Fitness': 'Healthcare & Fitness',
    };

    // Ensure the current values exist in the lists, otherwise use the first option
    String tempBusinessType = businessTypeOptions.contains(businessType) 
        ? businessType 
        : businessTypeOptions.first;
    
    // Check if category needs mapping, then validate
    String displayCategory = categoryMap[businessCategory] ?? businessCategory;
    String tempBusinessCategory = businessCategoryOptions.contains(displayCategory) 
        ? displayCategory 
        : businessCategoryOptions.first;
    
    final nameController = TextEditingController(text: businessName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Business Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Business Name Field
                  Text(
                    'Business Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter business name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Business Type Dropdown
                  Text(
                    'Business Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: tempBusinessType,
                      items: businessTypeOptions
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) => setSB(() => tempBusinessType = v!),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  Text(
                    'Business Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: tempBusinessCategory,
                      items: businessCategoryOptions
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (v) => setSB(() => tempBusinessCategory = v!),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            nameController.dispose();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            // Get the latest value from controller
                            final finalName = nameController.text.trim();
                            
                            if (finalName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Business name cannot be empty'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            try {
                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) {
                                throw Exception('User not found');
                              }

                              final activeBusinessId = user.userMetadata?['active_business_id'] as String?;

                              if (activeBusinessId == null) {
                                throw Exception('Business ID not found');
                              }

                              // Update business in database
                              await Supabase.instance.client
                                  .from('businesses')
                                  .update({
                                    'name': finalName,
                                    'category': tempBusinessCategory,
                                    'type': tempBusinessType,
                                  })
                                  .eq('id', activeBusinessId);

                              // Update user metadata with business profile
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(
                                  data: {
                                    'business_name': finalName,
                                    'business_category': tempBusinessCategory,
                                    'business_type': tempBusinessType,
                                  },
                                ),
                              );

                              if (mounted) {
                                // Update local state
                                setState(() {
                                  businessName = finalName;
                                  businessType = tempBusinessType;
                                  businessCategory = tempBusinessCategory;
                                });

                                nameController.dispose();
                                Navigator.pop(context);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Business profile updated successfully'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _switchBusiness() async {
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
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    final isActive =
                        user.userMetadata?['active_business_id'] ==
                        business['id'];

                    return Card(
                      color: isActive ? Colors.blue[50] : null,
                      child: ListTile(
                        title: Text(
                          business['name'],
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? Colors.blue : null,
                          ),
                        ),
                        subtitle: Text(
                          '${business['type']} • ${business['category']}',
                        ),
                        trailing:
                            isActive
                                ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                )
                                : PopupMenuButton(
                                  itemBuilder:
                                      (context) => [
                                        PopupMenuItem(
                                          child: const Text('Delete'),
                                          onTap: () async {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (_) => AlertDialog(
                                                    title: const Text(
                                                      'Delete Business',
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete "${business['name']}"? All cashbooks and transactions will be deleted.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          try {
                                                            // Delete business (cascades to cashbooks and transactions)
                                                            await Supabase
                                                                .instance
                                                                .client
                                                                .from(
                                                                  'businesses',
                                                                )
                                                                .delete()
                                                                .eq(
                                                                  'id',
                                                                  business['id'],
                                                                );

                                                            if (mounted) {
                                                              Navigator.pop(
                                                                context,
                                                              ); // Close delete dialog
                                                              Navigator.pop(
                                                                context,
                                                              ); // Close switch business dialog
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '${business['name']} deleted',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              );
                                                              // Reload businesses list
                                                              await Future.delayed(
                                                                const Duration(
                                                                  milliseconds:
                                                                      500,
                                                                ),
                                                              );
                                                              if (mounted) {
                                                                await _switchBusiness();
                                                              }
                                                            }
                                                          } catch (e) {
                                                            if (mounted) {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Error deleting business: $e',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                          },
                                        ),
                                      ],
                                ),
                        onTap:
                            isActive
                                ? null
                                : () async {
                                  try {
                                    // Update active business
                                    await Supabase.instance.client.auth
                                        .updateUser(
                                          UserAttributes(
                                            data: {
                                              'active_business_id':
                                                  business['id'],
                                              'business_name': business['name'],
                                              'business_type': business['type'],
                                              'business_category':
                                                  business['category'],
                                            },
                                          ),
                                        );

                                    if (mounted) {
                                      Navigator.pop(context);
                                      _loadBusinessProfile();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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

  Future<void> _createNewBusiness() async {
    final businessNameController = TextEditingController();
    String? selectedType;
    String? selectedCategory;

    final types = [
      'Sole Proprietorship',
      'Partnership',
      'Limited Liability Company (LLC)',
      'Corporation',
      'Non-profit Organization',
      'Other',
    ];

    final categories = [
      'Retail',
      'Wholesale',
      'Service',
      'Manufacturing',
      'Technology',
      'Healthcare',
      'Education',
      'Finance',
      'Hospitality',
      'Real Estate',
      'Other',
    ];

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSB) => AlertDialog(
                  title: const Text('Create New Business'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            hintText: 'Enter business name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          items:
                              types
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setSB(() => selectedType = v),
                          decoration: const InputDecoration(
                            labelText: 'Business Type',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          items:
                              categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setSB(() => selectedCategory = v),
                          decoration: const InputDecoration(
                            labelText: 'Business Category',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (businessNameController.text.isEmpty ||
                            selectedType == null ||
                            selectedCategory == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        try {
                          final userId =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (userId == null) return;

                          // Create new business
                          final response =
                              await Supabase.instance.client
                                  .from('businesses')
                                  .insert({
                                    'user_id': userId,
                                    'name': businessNameController.text.trim(),
                                    'type': selectedType,
                                    'category': selectedCategory,
                                  })
                                  .select();

                          if (response.isNotEmpty) {
                            final newBusinessId = response[0]['id'];

                            // Automatically switch to new business
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(
                                data: {
                                  'active_business_id': newBusinessId,
                                  'business_name':
                                      businessNameController.text.trim(),
                                  'business_type': selectedType,
                                  'business_category': selectedCategory,
                                },
                              ),
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              _loadBusinessProfile();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Business "${businessNameController.text.trim()}" created!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating business: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Business Card - Professional Design
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Business',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$businessType • $businessCategory',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // // Business Information Section - Professional Card
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       const Text(
            //         'Business Information',
            //         style: TextStyle(
            //           fontSize: 14,
            //           fontWeight: FontWeight.w600,
            //           color: Colors.grey,
            //           letterSpacing: 0.5,
            //         ),
            //       ),
            //       const SizedBox(height: 12),
            //       Container(
            //         decoration: BoxDecoration(
            //           color: isDark ? Colors.grey[900] : Colors.white,
            //           borderRadius: BorderRadius.circular(12),
            //           border: Border.all(
            //             color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            //             width: 1,
            //           ),
            //           boxShadow: [
            //             BoxShadow(
            //               color: Colors.black.withOpacity(0.05),
            //               blurRadius: 8,
            //               offset: const Offset(0, 2),
            //             ),
            //           ],
            //         ),
            //         child: Padding(
            //           padding: const EdgeInsets.all(20),
            //           child: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               // Business Name Row
            //               Padding(
            //                 padding: const EdgeInsets.only(bottom: 18),
            //                 child: Row(
            //                   children: [
            //                     Container(
            //                       width: 40,
            //                       height: 40,
            //                       decoration: BoxDecoration(
            //                         color: Colors.blue.withOpacity(0.1),
            //                         borderRadius: BorderRadius.circular(8),
            //                       ),
            //                       child: const Icon(
            //                         Icons.business_center_rounded,
            //                         color: Colors.blue,
            //                         size: 20,
            //                       ),
            //                     ),
            //                     const SizedBox(width: 12),
            //                     Expanded(
            //                       child: Column(
            //                         crossAxisAlignment: CrossAxisAlignment.start,
            //                         children: [
            //                           Text(
            //                             'Business Name',
            //                             style: TextStyle(
            //                               fontSize: 11,
            //                               fontWeight: FontWeight.w600,
            //                               color: Colors.grey[600],
            //                               letterSpacing: 0.3,
            //                             ),
            //                           ),
            //                           const SizedBox(height: 4),
            //                           Text(
            //                             businessName,
            //                             style: const TextStyle(
            //                               fontSize: 15,
            //                               fontWeight: FontWeight.w700,
            //                               color: Colors.black87,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                   ],
            //                 ),
            //               ),
            //
            //               // Business Type Row
            //               Padding(
            //                 padding: const EdgeInsets.only(bottom: 18),
            //                 child: Row(
            //                   children: [
            //                     Container(
            //                       width: 40,
            //                       height: 40,
            //                       decoration: BoxDecoration(
            //                         color: Colors.purple.withOpacity(0.1),
            //                         borderRadius: BorderRadius.circular(8),
            //                       ),
            //                       child: const Icon(
            //                         Icons.category_rounded,
            //                         color: Colors.purple,
            //                         size: 20,
            //                       ),
            //                     ),
            //                     const SizedBox(width: 12),
            //                     Expanded(
            //                       child: Column(
            //                         crossAxisAlignment: CrossAxisAlignment.start,
            //                         children: [
            //                           Text(
            //                             'Business Type',
            //                             style: TextStyle(
            //                               fontSize: 11,
            //                               fontWeight: FontWeight.w600,
            //                               color: Colors.grey[600],
            //                               letterSpacing: 0.3,
            //                             ),
            //                           ),
            //                           const SizedBox(height: 4),
            //                           Text(
            //                             businessType,
            //                             style: const TextStyle(
            //                               fontSize: 15,
            //                               fontWeight: FontWeight.w700,
            //                               color: Colors.black87,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                   ],
            //                 ),
            //               ),
            //
            //               // Category Row
            //               Padding(
            //                 padding: const EdgeInsets.only(bottom: 18),
            //                 child: Row(
            //                   children: [
            //                     Container(
            //                       width: 40,
            //                       height: 40,
            //                       decoration: BoxDecoration(
            //                         color: Colors.orange.withOpacity(0.1),
            //                         borderRadius: BorderRadius.circular(8),
            //                       ),
            //                       child: const Icon(
            //                         Icons.local_offer_rounded,
            //                         color: Colors.orange,
            //                         size: 20,
            //                       ),
            //                     ),
            //                     const SizedBox(width: 12),
            //                     Expanded(
            //                       child: Column(
            //                         crossAxisAlignment: CrossAxisAlignment.start,
            //                         children: [
            //                           Text(
            //                             'Category',
            //                             style: TextStyle(
            //                               fontSize: 11,
            //                               fontWeight: FontWeight.w600,
            //                               color: Colors.grey[600],
            //                               letterSpacing: 0.3,
            //                             ),
            //                           ),
            //                           const SizedBox(height: 4),
            //                           Text(
            //                             businessCategory,
            //                             style: const TextStyle(
            //                               fontSize: 15,
            //                               fontWeight: FontWeight.w700,
            //                               color: Colors.black87,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                   ],
            //                 ),
            //               ),
            //
            //               // Update Button
            //               SizedBox(
            //                 width: double.infinity,
            //                 height: 48,
            //                 child: ElevatedButton.icon(
            //                   icon: const Icon(Icons.edit_rounded),
            //                   label: const Text('Update Profile'),
            //                   style: ElevatedButton.styleFrom(
            //                     backgroundColor: Colors.blue,
            //                     foregroundColor: Colors.white,
            //                     shape: RoundedRectangleBorder(
            //                       borderRadius: BorderRadius.circular(10),
            //                     ),
            //                     elevation: 2,
            //                   ),
            //                   onPressed: _editBusinessProfile,
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // Business Management Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business Management',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _item(
                    context,
                    Icons.person_rounded,
                    'Business Profile',
                    'Name, Type, Category',
                    onTap: _editBusinessProfile,
                  ),
                  _item(
                    context,
                    Icons.group_rounded,
                    'Business Team',
                    'Add, remove or change role',
                  ),
                  _item(
                    context,
                    Icons.request_quote_rounded,
                    'Requests',
                    'Approve or deny requests',
                  ),
                  _item(
                    context,
                    Icons.business_rounded,
                    'Business Settings',
                    'Settings specific to this business',
                  ),
                  _item(
                    context,
                    Icons.swap_horiz_rounded,
                    'Switch Business',
                    'Change to another business',
                    onTap: _switchBusiness,
                  ),
                  _item(
                    context,
                    Icons.add_business_rounded,
                    'Create New Business',
                    'Add another business to your account',
                    onTap: _createNewBusiness,
                  ),
                ],
              ),
            ),

            // General Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'General Settings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _item(
                    context,
                    Icons.settings_rounded,
                    'App Settings',
                    'Language, Theme, Security, Backup',
                  ),
                  _item(
                    context,
                    Icons.person_rounded,
                    'Business Profile',
                    'Name, Mobile Number, Email',
                    onTap: _editBusinessProfile,
                  ),
                  _item(
                    context,
                    Icons.info_rounded,
                    'About CashBook',
                    'Privacy policy, T&C, About us',
                  ),
                ],
              ),
            ),

            // Logout Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _item(context, Icons.logout_rounded, 'Logout', '', isLogout: true),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isLogout 
          ? Colors.red.withOpacity(0.1)
          : (isDark ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLogout 
            ? Colors.red.withOpacity(0.2)
            : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (onTap != null) {
              onTap();
            } else if (isLogout) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          await Supabase.instance.client.auth.signOut();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logout failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title clicked'),
                  duration: const Duration(milliseconds: 800),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isLogout 
                      ? Colors.red.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? Colors.red : Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLogout ? Colors.red : Colors.black87,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLogout) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Subscription Screen (screenshot-based) ----------------

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _plan = 'Starter';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Subscription'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Please subscribe to continue using CashBook.'),
          const SizedBox(height: 12),
          const Text('Best suited for you:'),
          const SizedBox(height: 8),
          _planTile(
            'Starter',
            'BDT 320.00 /month',
            'Free for 2 weeks →\nBDT 320.00 /month afterwards\n\nManage 1 Business\nUp to 2 members in each business',
          ),
          const SizedBox(height: 12),
          const Text('Choose another plan'),
          const SizedBox(height: 8),
          _planTile(
            'Essentials',
            'BDT 650.00 /month',
            'Free for 2 weeks →\n\nManage 2 Businesses\nUp to 4 members in each business',
          ),
          _planTile(
            'Professional',
            'BDT 1,000.00 /month',
            'Free for 2 weeks →\n\nManage 3 Businesses',
          ),
          _planTile(
            'Business',
            'BDT 2,400.00 /month',
            'Free for 2 weeks →\n\nManage 10 Businesses\nUp to 15 members',
          ),
          _planTile(
            'Enterprise',
            'BDT 8,200.00 /month',
            'Free for 2 weeks →\n\nUnlimited Business\nUnlimited members',
          ),
          const SizedBox(height: 16),
          const Text('Common features & permissions'),
          const Text(
            'You can add unlimited books in all the plans. Download reports.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Subscribed to $_plan')));
                Navigator.pop(context);
              },
              child: const Text('SUBSCRIBE'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _planTile(String value, String price, String desc) {
    final selected = _plan == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? Colors.green : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _plan,
        onChanged: (v) => setState(() => _plan = v!),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Text(desc),
      ),
    );
  }
}
