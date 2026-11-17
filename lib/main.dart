import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_constants.dart';
import 'config/app_theme.dart';
import 'screens/cafe_admin_panel.dart';
import 'screens/cafeteria_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final initialDarkMode = preferences.getBool('cafe_dark_mode') ?? false;

  var supabaseConfigured = false;
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['CAFE_SUPABASE_URL']?.trim() ?? '';
    final anonKey = dotenv.env['CAFE_SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isNotEmpty &&
        anonKey.isNotEmpty &&
        !url.contains('YOUR_PROJECT_REF') &&
        !anonKey.contains('YOUR_PUBLISHABLE_KEY')) {
      await Supabase.initialize(url: url, anonKey: anonKey);
      supabaseConfigured = true;
    }
  } catch (e) {
    debugPrint('Cafe Supabase is not configured: $e');
  }

  runApp(
    BAUSTNexusApp(
      supabaseConfigured: supabaseConfigured,
      initialDarkMode: initialDarkMode,
    ),
  );
}

class BAUSTNexusApp extends StatelessWidget {
  const BAUSTNexusApp({
    super.key,
    required this.supabaseConfigured,
    this.initialDarkMode = false,
  });

  final bool supabaseConfigured;
  final bool initialDarkMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeController(isDarkMode: initialDarkMode),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          themeAnimationDuration: Duration.zero,
          home: supabaseConfigured ? null : const SupabaseSetupScreen(),
          initialRoute: supabaseConfigured ? '/' : null,
          routes: supabaseConfigured
              ? {
                  '/': (context) => const LoginScreen(),
                  '/cafeteria': (context) => const CafeteriaScreen(),
                  '/login': (context) => const LoginScreen(),
                  '/signup': (context) => const SignupScreen(),
                  '/cafe_admin': (context) => const CafeAdminPanel(),
                }
              : const {},
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(child: Text('Page not found')),
            ),
          ),
        ),
      ),
    );
  }
}

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56),
                SizedBox(height: 16),
                Text(
                  'Dedicated cafe database is not configured',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Create a separate Supabase project, run the SQL migration in '
                  'supabase/migrations, then set CAFE_SUPABASE_URL and '
                  'CAFE_SUPABASE_ANON_KEY in baust_nexus/.env.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
