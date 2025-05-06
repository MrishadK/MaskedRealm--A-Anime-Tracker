import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/theme_provider.dart';
import 'app_open_ad_manager.dart';
import 'dashboard.dart';
import 'auth_page.dart';
import 'register_page.dart';

final AppOpenAdManager appOpenAdManager = AppOpenAdManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  appOpenAdManager.loadAd(); // Preload App Open Ad

  await Supabase.initialize(
    url: 'https://bhnvknbfimtalosfczcf.supabase.co',
    anonKey:
        '<supabase base key',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final hasSession = Supabase.instance.client.auth.currentSession != null;

  runApp(MyApp(
    rememberMe: rememberMe,
    hasSession: hasSession,
  ));
}

class MyApp extends StatefulWidget {
  final bool rememberMe;
  final bool hasSession;

  const MyApp({
    super.key,
    required this.rememberMe,
    required this.hasSession,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appOpenAdManager.showAdIfAvailable(); // Show App Open Ad on resume
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Masked Realm',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            initialRoute: (widget.rememberMe && widget.hasSession)
                ? '/dashboard'
                : '/login',
            routes: {
              '/login': (context) => const AuthPage(),
              '/dashboard': (context) => const Dashboard(),
              '/register': (context) => const RegisterPage(),
            },
          );
        },
      ),
    );
  }
}
