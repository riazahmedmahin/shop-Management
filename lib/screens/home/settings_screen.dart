import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String businessName;
  late String businessType;
  late String businessCategory;

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

    final categoryMap = {
      'Healthcare': 'Healthcare & Fitness',
      'Healthcare & Fitness': 'Healthcare & Fitness',
    };

    String tempBusinessType =
        businessTypeOptions.contains(businessType)
            ? businessType
            : businessTypeOptions.first;

    String displayCategory = categoryMap[businessCategory] ?? businessCategory;
    String tempBusinessCategory =
        businessCategoryOptions.contains(displayCategory)
            ? displayCategory
            : businessCategoryOptions.first;

    final nameController = TextEditingController(text: businessName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSB) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
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
                              items:
                                  businessTypeOptions
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setSB(() => tempBusinessType = v!),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
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
                              items:
                                  businessCategoryOptions
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setSB(() => tempBusinessCategory = v!),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final finalName =
                                        nameController.text.trim();

                                    if (finalName.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Business name cannot be empty',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final user =
                                          Supabase
                                              .instance
                                              .client
                                              .auth
                                              .currentUser;
                                      if (user == null) {
                                        throw Exception('User not found');
                                      }

                                      final activeBusinessId =
                                          user.userMetadata?['active_business_id']
                                              as String?;

                                      if (activeBusinessId == null) {
                                        throw Exception(
                                          'Business ID not found',
                                        );
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
                                      await Supabase.instance.client.auth
                                          .updateUser(
                                            UserAttributes(
                                              data: {
                                                'business_name': finalName,
                                                'business_category':
                                                    tempBusinessCategory,
                                                'business_type':
                                                    tempBusinessType,
                                              },
                                            ),
                                          );

                                      if (mounted) {
                                        setState(() {
                                          businessName = finalName;
                                          businessType = tempBusinessType;
                                          businessCategory =
                                              tempBusinessCategory;
                                        });

                                        nameController.dispose();
                                        Navigator.pop(context);

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✓ Business profile updated successfully',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
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
                                              'Error: ${e.toString()}',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
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

      if (!mounted) return; // Show dialog with business list
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Switch Business'),
              contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            isActive
                                ? const BorderSide(color: Colors.blue, width: 2)
                                : BorderSide(color: Colors.grey.shade200),
                      ),
                      color: isActive ? Colors.blue[50] : Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            isActive
                                ? null
                                : () async {
                                  try {
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      isActive
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.business_outlined,
                                  size: 24,
                                  color:
                                      isActive ? Colors.blue : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      business['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color:
                                            isActive
                                                ? Colors.blue[800]
                                                : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${business['type']} • ${business['category']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 22,
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (_) => AlertDialog(
                                            title: const Text(
                                              'Delete Business',
                                            ),
                                            content: Text(
                                              'Delete "${business['name']}"? All cashbooks and transactions will be deleted.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  try {
                                                    await Supabase
                                                        .instance
                                                        .client
                                                        .from('businesses')
                                                        .delete()
                                                        .eq(
                                                          'id',
                                                          business['id'],
                                                        );
                                                    if (mounted) {
                                                      Navigator.pop(context);
                                                      Navigator.pop(context);
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '${business['name']} deleted',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                      await Future.delayed(
                                                        const Duration(
                                                          milliseconds: 500,
                                                        ),
                                                      );
                                                      if (mounted) {
                                                        await _switchBusiness();
                                                      }
                                                    }
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
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
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red[700],
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCurrentBusiness() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final activeBusinessId = user.userMetadata?['active_business_id'];
    if (activeBusinessId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red[600], size: 26),
                const SizedBox(width: 8),
                const Text('Delete Business'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete "$businessName"?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    '⚠️ This will permanently delete all cashbooks and transactions. This action cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('businesses')
          .delete()
          .eq('id', activeBusinessId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$businessName" deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
        await Supabase.instance.client.auth.signOut();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting business: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
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
                  _item(
                    context,
                    Icons.delete_forever_rounded,
                    'Delete Business',
                    'Permanently delete this business',
                    isDelete: true,
                    onTap: _deleteCurrentBusiness,
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
                  _item(
                    context,
                    Icons.logout_rounded,
                    'Logout',
                    '',
                    isLogout: true,
                  ),
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
    bool isDelete = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRed = isLogout || isDelete;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isRed
                ? Colors.red.withOpacity(0.05)
                : (isDark ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isRed
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
                builder:
                    (_) => AlertDialog(
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
                    color:
                        isRed
                            ? Colors.red.withOpacity(0.15)
                            : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isRed ? Colors.red : Colors.blue,
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
                          color: isRed ? Colors.red : Colors.black87,
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
