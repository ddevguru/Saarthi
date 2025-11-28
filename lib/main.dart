/**
 * SAARTHI Flutter App - Main Entry Point
 * Ultra-low-cost IoT Assistive System for India
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// LOCAL FILES
import 'l10n/app_localizations.dart';
import 'core/app_theme.dart';
import 'data/services/auth_service.dart';

// AUTH SCREENS
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/signup_screen.dart';

// MAIN SCREENS
import 'presentation/screens/user/user_home_screen.dart';
import 'presentation/screens/parent/parent_home_screen.dart';
import 'presentation/screens/navigation/navigation_assist_screen.dart';
import 'presentation/screens/settings/device_pairing_screen.dart';
import 'presentation/screens/user/emergency_contacts_screen.dart';
import 'presentation/widgets/glassmorphic_container.dart';
import 'core/neon_colors.dart';

void main() {
  runApp(const SaarthiApp());
}

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'SAARTHI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        supportedLocales: const [
          Locale('en', ''),
          Locale('hi', ''),
        ],

        initialRoute: '/',

        routes: {
          '/': (context) => const SplashScreen(),

          // Auth Screens
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),

          // Main Screens
          '/user-home': (context) => const UserHomeScreen(),
          '/parent-home': (context) => const ParentHomeScreen(),
          '/navigation-assist': (context) => const NavigationAssistScreen(),

          // Settings & Others
          '/device-pairing': (context) => const DevicePairingScreen(),
          '/emergency-contacts': (context) => const EmergencyContactsScreen(),

          // Placeholder pages
          '/quick-messages': (context) => const QuickMessagesScreen(),
          '/safe-zones': (context) => const SafeZonesScreen(),
          '/trip-control': (context) => const TripControlScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

//
// ------------------ SPLASH SCREEN ------------------
//

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Move to LoginScreen
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A1A), // Dark gray/black
              const Color(0xFF2D2D2D), // Slightly lighter dark
              const Color(0xFF1A1A1A), // Back to dark
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo without circle background
                      Image.asset(
                        "assets/images/logo.png",
                        width: isSmallScreen ? 180 : 240,
                        height: isSmallScreen ? 180 : 240,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.accessibility_new,
                            size: isSmallScreen ? 160 : 220,
                            color: NeonColors.lightNeonPink,
                          );
                        },
                      ),

                      SizedBox(height: isSmallScreen ? 30 : 40),

                      // App Name with Light Neon Gradient
                      ShaderMask(
                        shaderCallback: NeonColors.lightNeonGradientShader,
                        child: Text(
                          'SAARTHI',
                          style: NeonColors.neonText(
                            fontSize: isSmallScreen ? 40 : 52,
                            fontWeight: FontWeight.bold,
                            color: NeonColors.lightNeonPink,
                          ).copyWith(
                            letterSpacing: 3,
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 10 : 15),

                      // Tagline with Light Neon
                      Text(
                        'Smart IoT Assistive System',
                        style: NeonColors.neonText(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          color: NeonColors.lightNeonCyan,
                        ).copyWith(
                          letterSpacing: 1,
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 50 : 70),

                      // Enhanced Loading Indicator with Glassmorphism
                      GlassmorphicContainer(
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        borderRadius: 50,
                        blur: 10,
                        gradientColors: [
                          const Color(0xFFFF6B9D).withOpacity(0.3),
                          const Color(0xFF4ECDC4).withOpacity(0.2),
                        ],
                        child: SizedBox(
                          width: isSmallScreen ? 35 : 45,
                          height: isSmallScreen ? 35 : 45,
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B9D), // Pink
                            ),
                            strokeWidth: 3.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//
// -------- Placeholder Pages (TEMP) --------
//

class QuickMessagesScreen extends StatelessWidget {
  const QuickMessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Quick Messages")),
        body: const Center(child: Text("Coming soon")));
  }
}

class SafeZonesScreen extends StatelessWidget {
  const SafeZonesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Safe Zones")),
        body: const Center(child: Text("Coming soon")));
  }
}

class TripControlScreen extends StatelessWidget {
  const TripControlScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Trip Control")),
        body: const Center(child: Text("Coming soon")));
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Coming soon")));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text("Device Pairing"),
            subtitle: const Text("Generate token for ESP32 device"),
            onTap: () => Navigator.pushNamed(context, "/device-pairing"),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: const Text("English / हिंदी"),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.emergency),
            title: const Text("Emergency Contacts"),
            onTap: () =>
                Navigator.pushNamed(context, "/emergency-contacts"),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
