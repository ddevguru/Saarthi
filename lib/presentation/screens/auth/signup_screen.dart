/**
 * SAARTHI Flutter App - Signup Screen
 * Intelligent signup with real-time validation and smart features
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/app_theme.dart';
import '../../widgets/loading_dialog.dart';
import 'package:saarthi/l10n/app_localizations.dart';

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
  bool _obscureConfirmPassword = true;
  String? _selectedRole;
  String _selectedLanguage = 'en';
  String _selectedDisability = 'NONE';
  
  // Password strength tracking
  PasswordStrength _passwordStrength = PasswordStrength.none;
  
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      if (password.isEmpty) {
        _passwordStrength = PasswordStrength.none;
      } else if (password.length < 6) {
        _passwordStrength = PasswordStrength.weak;
      } else if (password.length < 8 || 
                 !password.contains(RegExp(r'[A-Z]')) ||
                 !password.contains(RegExp(r'[0-9]'))) {
        _passwordStrength = PasswordStrength.fair;
      } else if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        _passwordStrength = PasswordStrength.good;
      } else {
        _passwordStrength = PasswordStrength.strong;
      }
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    // Smart suggestion for common typos
    if (value.contains('@gmial.com')) {
      return 'Did you mean @gmail.com?';
    }
    if (value.contains('@yahooo.com')) {
      return 'Did you mean @yahoo.com?';
    }
    
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove all non-digits
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    if (digitsOnly.length > 10) {
      return 'Phone number should be 10 digits';
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  void _formatPhoneNumber(String value) {
    // Remove all non-digits
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format as XXX-XXX-XXXX
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }
    
    if (formatted != value) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    showLoadingDialog(context);

    try {
      final result = await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        password: _passwordController.text,
        role: _selectedRole!,
        languagePreference: _selectedLanguage,
        disabilityType: _selectedDisability,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (result['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! Please login.'),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate back to login
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.dangerColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();
    
    Color color;
    String label;
    double strength;
    
    switch (_passwordStrength) {
      case PasswordStrength.none:
        return const SizedBox.shrink();
      case PasswordStrength.weak:
        color = Colors.red;
        label = 'Weak';
        strength = 0.25;
        break;
      case PasswordStrength.fair:
        color = Colors.orange;
        label = 'Fair';
        strength = 0.5;
        break;
      case PasswordStrength.good:
        color = Colors.blue;
        label = 'Good';
        strength = 0.75;
        break;
      case PasswordStrength.strong:
        color = Colors.green;
        label = 'Strong';
        strength = 1.0;
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getPasswordHint(),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _getPasswordHint() {
    final password = _passwordController.text;
    if (password.isEmpty) return '';
    
    List<String> hints = [];
    if (password.length < 8) hints.add('Use 8+ characters');
    if (!password.contains(RegExp(r'[A-Z]'))) hints.add('Add uppercase letter');
    if (!password.contains(RegExp(r'[0-9]'))) hints.add('Add a number');
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) hints.add('Add special character');
    
    return hints.isEmpty ? 'Strong password!' : hints.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join SAARTHI to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Name field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    hintText: 'example@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                
                // Phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.phone,
                    hintText: '123-456-7890',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validatePhone,
                  onChanged: (value) {
                    if (value.length <= 12) {
                      _formatPhoneNumber(value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    hintText: 'Create a strong password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validatePassword,
                  onChanged: _checkPasswordStrength,
                ),
                _buildPasswordStrengthIndicator(),
                const SizedBox(height: 20),
                
                // Confirm Password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 32),
                
                // Role selection
                Text(
                  l10n.selectRole,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        'USER',
                        'User',
                        Icons.person,
                        _selectedRole == 'USER',
                        () => setState(() => _selectedRole = 'USER'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleCard(
                        'PARENT',
                        'Parent',
                        Icons.family_restroom,
                        _selectedRole == 'PARENT',
                        () => setState(() => _selectedRole = 'PARENT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Language preference
                Text(
                  'Language Preference',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildOptionChip(
                        'English',
                        Icons.language,
                        _selectedLanguage == 'en',
                        () => setState(() => _selectedLanguage = 'en'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOptionChip(
                        'हिंदी',
                        Icons.translate,
                        _selectedLanguage == 'hi',
                        () => setState(() => _selectedLanguage = 'hi'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Disability type (optional)
                Text(
                  'Accessibility Needs (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDisabilityChip('NONE', 'None', _selectedDisability == 'NONE'),
                    _buildDisabilityChip('VISUAL', 'Visual', _selectedDisability == 'VISUAL'),
                    _buildDisabilityChip('HEARING', 'Hearing', _selectedDisability == 'HEARING'),
                    _buildDisabilityChip('SPEECH', 'Speech', _selectedDisability == 'SPEECH'),
                    _buildDisabilityChip('MULTIPLE', 'Multiple', _selectedDisability == 'MULTIPLE'),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Sign up button
                ElevatedButton(
                  onPressed: _handleSignup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, size: 20, color: AppTheme.primaryColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabilityChip(String value, String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedDisability = selected ? value : 'NONE';
        });
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

enum PasswordStrength {
  none,
  weak,
  fair,
  good,
  strong,
}

