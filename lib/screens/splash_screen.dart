import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
