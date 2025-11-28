/**
 * SAARTHI Flutter App - Login Screen (Updated UI Without Banner Image)
 */

import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../data/services/auth_service.dart';
import '../../../core/app_theme.dart';
import '../../widgets/loading_dialog.dart';
import '../../widgets/glassmorphic_container.dart';
import '../../../core/neon_colors.dart';
import 'package:saarthi/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    showLoadingDialog(context);

    try {
      final result = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loader

      if (result['success'] == true) {
        final role = result['user'].role;

        if (role == 'PARENT') {
          Navigator.pushReplacementNamed(context, '/parent-home');
        } else if (role == 'ADMIN') {
          Navigator.pushReplacementNamed(context, '/admin-panel');
        } else {
          Navigator.pushReplacementNamed(context, '/user-home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A1A), // Dark gray/black
              const Color(0xFF2D2D2D), // Slightly lighter dark
              const Color(0xFF1F1F1F), // Dark
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: isVerySmallScreen ? 10 : (isSmallScreen ? 15 : 20),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: isVerySmallScreen ? 20 : (isSmallScreen ? 30 : 50)),

                      // ---------- APP LOGO & TITLE ----------
                      Image.asset(
                        "assets/images/logo.png",
                        width: isSmallScreen ? 160 : 200,
                        height: isSmallScreen ? 160 : 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.accessibility_new,
                            size: isSmallScreen ? 140 : 180,
                            color: NeonColors.lightNeonPink,
                          );
                        },
                      ),

                      SizedBox(height: isSmallScreen ? 20 : 30),

                      // App Name with Light Neon Gradient
                     

                      // Tagline with Light Neon
                      Text(
                        "Smart IoT Assistive System",
                        style: NeonColors.neonText(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w400,
                          color: NeonColors.lightNeonCyan,
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 30 : 50),

                      // ---------- GLASSMORPHIC LOGIN FORM ----------
                      GlassmorphicContainer(
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                        borderRadius: 30,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field with Glassmorphism
                              GlassmorphicContainer(
                                padding: EdgeInsets.zero,
                                borderRadius: 15,
                                blur: 8,
                                gradientColors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                ],
                                child: TextFormField(
                                  controller: _emailController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: l10n.email,
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.email,
                                      color: Color(0xFFFF6B9D), // Pink
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Please enter email";
                                    }
                                    if (!value.contains('@')) {
                                      return "Invalid email";
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 18 : 20),

                              // Password Field with Glassmorphism
                              GlassmorphicContainer(
                                padding: EdgeInsets.zero,
                                borderRadius: 15,
                                blur: 8,
                                gradientColors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                ],
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: l10n.password,
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock,
                                      color: Color(0xFF4ECDC4), // Cyan/Blue
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Please enter password";
                                    }
                                    if (value.length < 6) {
                                      return "Minimum 6 characters required";
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 25 : 30),

                              // ---------- LOGIN BUTTON ----------
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B9D), // Pink
                                      Color(0xFF4ECDC4), // Cyan/Blue
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B9D).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 14 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.login,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 15 : 20),

                              // ---------- SIGN-UP LINK ----------
                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, "/signup"),
                                  child: Text(
                                    "Don't have an account? ${l10n.signup}",
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.white.withOpacity(0.8),
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 20 : 30),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
