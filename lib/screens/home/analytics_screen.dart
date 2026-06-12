import 'package:flutter/material.dart';

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
