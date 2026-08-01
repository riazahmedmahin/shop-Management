import 'package:flutter/material.dart';
import '../../utils/responsive_helper.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = R(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: r.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: r.space(20)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.currency_exchange,
                          size: r.icon(40),
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: r.space(8)),
                        Text(
                          'CASHBOOK',
                          style: TextStyle(
                            fontSize: r.font(32),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.space(36)),
                    Container(
                      width: r.splashCircleSize,
                      height: r.splashCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: r.splashIconSize,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: r.space(16)),
                    Text(
                      'Hello',
                      style: TextStyle(
                        fontSize: r.font(22),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: r.space(8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group, size: r.icon(20)),
                        SizedBox(width: 5),
                        Text('1 member', style: TextStyle(fontSize: r.font(13))),
                      ],
                    ),
                    SizedBox(height: r.space(60)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.security, color: Colors.green, size: r.icon(24)),
                              SizedBox(height: 4),
                              Text(
                                '100% Safe & Secure',
                                style: TextStyle(fontSize: r.font(12)),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.cloud_upload, color: Colors.blue, size: r.icon(24)),
                              SizedBox(height: 4),
                              Text(
                                'Auto Data Backup',
                                style: TextStyle(fontSize: r.font(12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.space(20)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
