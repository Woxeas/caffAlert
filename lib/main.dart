import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'timer_provider.dart';
import 'coffee_stats_provider.dart';
import 'timer_screen.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'name_screen.dart';

// Build-time konstanty předávané přes dart-define
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace Sentry s rozšířenou konfigurací.
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.environment = 'production';
      options.release = 'caffalert@1.0.0+1';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      // Inicializace Supabase s využitím build-time konstant.
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TimerProvider()),
            ChangeNotifierProvider(create: (_) => CoffeeStatsProvider()),
          ],
          child: const CaffAlertApp(),
        ),
      );
    },
  );
}

class CaffAlertApp extends StatefulWidget {
  const CaffAlertApp({Key? key}) : super(key: key);

  @override
  State<CaffAlertApp> createState() => _CaffAlertAppState();
}

class _CaffAlertAppState extends State<CaffAlertApp> {
  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Poslouchá změny v autentizaci a vyvolá rebuild
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaffAlert',
      theme: ThemeData(
        fontFamily: 'Raleway',
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: const Color.fromARGB(255, 226, 209, 197),
      ),
      // Pokud není uživatel přihlášen, zobrazí se AuthScreen.
      // Pokud je přihlášen, HomeSelector rozhodne, zda zobrazit NameScreen (pokud jméno není nastaveno)
      // nebo MainScreen (pokud jméno existuje).
      home: Supabase.instance.client.auth.currentSession == null
          ? const AuthScreen()
          : const HomeSelector(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// HomeSelector provádí dotaz na Supabase, aby zjistil, zda má aktuální uživatel nastavené jméno.
class HomeSelector extends StatelessWidget {
  const HomeSelector({Key? key}) : super(key: key);

  Future<bool> _hasName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return false;

    final profile = response as Map<String, dynamic>;
    final name = profile['name'];
    return name != null && name.toString().trim().isNotEmpty;
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return const Scaffold(
              body: Center(child: Text('Error loading profile')));
        } else {
          final hasName = snapshot.data ?? false;
          return hasName ? MainScreen() : const NameScreen();
        }
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  final PageController _pageController = PageController();

  MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: const [
          TimerScreen(),    // Hlavní obrazovka s časovačem
          DashboardScreen(), // Dashboard obrazovka
          SettingsScreen(),  // Nastavení
        ],
      ),
    );
  }
}
