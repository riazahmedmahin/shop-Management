import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/faq_item.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('WhatsApp not available')));
      }
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
