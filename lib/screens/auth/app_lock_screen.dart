import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class AppLockScreen extends StatefulWidget {
  final Widget child; // The actual app content to show after unlock

  const AppLockScreen({super.key, required this.child});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
      });
      
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();
          
      if (!canAuthenticate) {
        // If device doesn't support biometrics, just let them in (or handle differently)
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
        });
        return;
      }

      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access your CashBook',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      
      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 20),
            const Text(
              'App Locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Unlock to access your secure data',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (_isAuthenticating)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text('Unlock', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
