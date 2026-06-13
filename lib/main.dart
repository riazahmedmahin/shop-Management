import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/cashbook_app_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wkmrbwfzxlbapqqragzb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbXJid2Z6eGxiYXBxcXJhZ3piIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxNTgzNDQsImV4cCI6MjA3OTczNDM0NH0.sC1YOmqtya4P8RTeAZi8PGnJaP81c_Fn8rYSczuTn0M',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Stream<AuthState> _authStateStream;
  bool _timerFinished = false;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _timerFinished = true;
        });
      }
    });
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
          if (!_timerFinished ||
              snapshot.connectionState == ConnectionState.waiting) {
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
