/**
 * SAARTHI Flutter App - Main Entry Point
 * Ultra-low-cost IoT Assistive System for India
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:saarthi/l10n/app_localizations.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'data/services/auth_service.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/signup_screen.dart';
import 'presentation/screens/user/user_home_screen.dart';
import 'presentation/screens/parent/parent_home_screen.dart';
import 'presentation/screens/navigation/navigation_assist_screen.dart' as nav;
import 'presentation/screens/settings/device_pairing_screen.dart';
import 'presentation/screens/user/emergency_contacts_screen.dart';

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
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/user-home': (context) => const UserHomeScreen(),
          '/parent-home': (context) => const ParentHomeScreen(),
          '/navigation-assist': (context) => const nav.NavigationAssistScreen(),
          '/quick-messages': (context) => const QuickMessagesScreen(),
          '/safe-zones': (context) => const SafeZonesScreen(),
          '/trip-control': (context) => const TripControlScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/device-pairing': (context) => const DevicePairingScreen(),
          '/emergency-contacts': (context) => const EmergencyContactsScreen(),
        },
      ),
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    
    if (isLoggedIn) {
      final role = await authService.getUserRole();
      if (role == AppConstants.roleParent) {
        Navigator.pushReplacementNamed(context, '/parent-home');
      } else {
        Navigator.pushReplacementNamed(context, '/user-home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.accessibility_new,
              size: 100,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'SAARTHI',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'IoT Assistive System',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}



class QuickMessagesScreen extends StatelessWidget {
  const QuickMessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Messages')),
      body: const Center(child: Text('Quick messages screen - Coming soon')),
    );
  }
}

class SafeZonesScreen extends StatelessWidget {
  const SafeZonesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Zones')),
      body: const Center(child: Text('Safe zones screen - Coming soon')),
    );
  }
}

class TripControlScreen extends StatelessWidget {
  const TripControlScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Control')),
      body: const Center(child: Text('Trip control screen - Coming soon')),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Notifications screen - Coming soon')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Device Pairing'),
            subtitle: const Text('Generate token for ESP32 device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/device-pairing');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English / हिंदी'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Language settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.emergency),
            title: const Text('Emergency Contacts'),
            subtitle: const Text('Manage emergency contacts for SOS alerts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/emergency-contacts');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final authService = AuthService();
              await authService.logout();
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
