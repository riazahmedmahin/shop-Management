import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../../models/business_setup_data.dart';
import '../home/cashbook_app_wrapper.dart';

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
  int _currentStep = 0; // 0 = account info, 1 = business name, 2 = category, 3 = type

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Retail':
        return Icons.store_outlined;
      case 'Wholesale':
        return Icons.local_shipping_outlined;
      case 'Service':
        return Icons.handyman_outlined;
      case 'Manufacturing':
        return Icons.precision_manufacturing_outlined;
      case 'Technology':
        return Icons.desktop_mac_outlined;
      case 'Healthcare':
        return Icons.local_hospital_outlined;
      case 'Education':
        return Icons.school_outlined;
      case 'Finance':
        return Icons.account_balance_outlined;
      case 'Hospitality':
        return Icons.hotel_outlined;
      case 'Real Estate':
        return Icons.apartment_outlined;
      default:
        return Icons.apps_outlined;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Sole Proprietorship':
        return Icons.person_outline;
      case 'Partnership':
        return Icons.people_outline;
      case 'Limited Liability Company (LLC)':
        return Icons.business_center_outlined;
      case 'Corporation':
        return Icons.business_outlined;
      case 'Non-profit Organization':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.business_outlined;
    }
  }

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
    // Step 0: Validate account info
    if (_currentStep == 0) {
      if (_fullName.text.isEmpty ||
          _email.text.isEmpty ||
          _password.text.isEmpty ||
          _confirmPassword.text.isEmpty) {
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

      // Move to step 1
      setState(() => _currentStep = 1);
      return;
    }

    // Step 1: Validate business name
    if (_currentStep == 1) {
      if (_businessName.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter business name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    // Step 2: Validate business category
    if (_currentStep == 2) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a business category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 3);
      return;
    }

    // Step 3: Validate business type and create account
    if (_currentStep == 3) {
      if (_selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a business type'),
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
                  onTap: () {
                    if (_currentStep == 1) {
                      setState(() => _currentStep = 0);
                    } else {
                      Navigator.pop(context);
                    }
                  },
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

                // Header with Step Indicator
                Text(
                  _currentStep == 0
                      ? 'Account Information'
                      : _currentStep == 1
                          ? 'Business Name'
                          : _currentStep == 2
                              ? 'Business Category'
                              : 'Business Type',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1} of 4',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Step 1: Account Information
                if (_currentStep == 0) ...[
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
                  const SizedBox(height: 24),

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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Next Button (Step 1)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Already have account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Step 2: Business Name
                if (_currentStep == 1) ...[
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
                  const SizedBox(height: 24),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Step 3: Business Category
                if (_currentStep == 2) ...[
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children:
                        _categories
                            .map(
                              (cat) => GestureDetector(
                                onTap: () {
                                  setState(() => _selectedCategory = cat);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    border: Border.all(
                                      color: _selectedCategory == cat
                                          ? Colors.blue[600]!
                                          : Colors.grey[300]!,
                                      width:
                                          _selectedCategory == cat ? 2.5 : 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(cat),
                                          color: Colors.blue[600],
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            cat,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Step 4: Business Type
                if (_currentStep == 3) ...[
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children:
                        _types
                            .map(
                              (type) => GestureDetector(
                                onTap: () {
                                  setState(() => _selectedType = type);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    border: Border.all(
                                      color: _selectedType == type
                                          ? Colors.blue[600]!
                                          : Colors.grey[300]!,
                                      width: _selectedType == type ? 2.5 : 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getTypeIcon(type),
                                          color: Colors.blue[600],
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
                      child: _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
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
                ],
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
                                      color: Colors.blue,
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
