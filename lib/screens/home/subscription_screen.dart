import 'package:flutter/material.dart';

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
