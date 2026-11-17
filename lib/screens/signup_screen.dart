import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import '../widgets/theme_mode_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String _selectedRole = 'customer';

  static const _roles = <String, String>{
    'customer': 'Customer / Student',
    'manager': 'Manager',
    'cashier': 'Cashier',
    'chef': 'Chef / Kitchen Staff',
    'waiter': 'Waiter / Service Staff',
    'supplier': 'Supplier',
    'university_authority': 'University Authority',
    'cafe_admin': 'Cafe Owner / Management',
  };

  bool get _isOwnerEmail =>
      _emailController.text.trim().toLowerCase() == 'cafeadmin@gmail.com';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isOwnerEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The Cafe Owner account must be provisioned securely by the project owner. Sign in after setup.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final emailConfirmationRequired = await auth.signUpCafeCustomer(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      requestedRole: _selectedRole,
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    if (!mounted) return;
    final errorMessage = auth.errorMessage;
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
      auth.clearError();
      return;
    }

    if (auth.currentUser != null) {
      final user = auth.currentUser!;
      if (user.status != 'approved') {
        await auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account request submitted. Sign in after Cafe Owner approval.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        user.role == 'cafe_admin' ? '/cafe_admin' : '/cafeteria',
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          emailConfirmationRequired
              ? 'Account created. Confirm your email before signing in.'
              : 'Customer account created. Please sign in.',
        ),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Customer Account',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: const [ThemeModeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildField(
                          controller: _nameController,
                          label: 'Full name',
                          hint: 'Enter your name',
                          icon: Icons.person_outline,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter your name'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _emailController,
                          label: 'Email address',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (!_isOwnerEmail &&
                                _selectedRole == 'cafe_admin') {
                              setState(() => _selectedRole = 'customer');
                            } else {
                              setState(() {});
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _phoneController,
                          label: 'Phone number (optional)',
                          hint: 'Enter your phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Select your role',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: _roles.entries
                              .where((entry) =>
                                  entry.key != 'cafe_admin' || _isOwnerEmail)
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _selectedRole = role);
                            }
                          },
                        ),
                        if (_selectedRole != 'customer') ...[
                          const SizedBox(height: 8),
                          Text(
                            _selectedRole == 'cafe_admin'
                                ? 'The Cafe Owner account is provisioned securely by the project owner.'
                                : 'Staff and stakeholder accounts require Cafe Owner approval before sign-in.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'At least 6 characters',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _confirmPasswordController,
                          label: 'Confirm password',
                          hint: 'Re-enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirmation,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                            icon: Icon(
                              _obscureConfirmation
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthService>(
                          builder: (context, auth, _) => SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _createAccount,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create Account'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text('Already have an account? Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
