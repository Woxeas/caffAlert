import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv
import 'package:supabase_flutter/supabase_flutter.dart';
import 'timer_provider.dart';
import 'coffee_stats_provider.dart';
import 'timer_screen.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart'; // Přihlašovací/registrace obrazovka
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Načti .env soubor s proměnnými
 await dotenv.load(fileName: "assets/.env");

  // Inicializace Supabase s použitím env proměnných
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => CoffeeStatsProvider()),
      ],
      child: CaffAlertApp(),
    ),
  );
}

class CaffAlertApp extends StatefulWidget {
  const CaffAlertApp({super.key});

  @override
  _CaffAlertAppState createState() => _CaffAlertAppState();
}

class _CaffAlertAppState extends State<CaffAlertApp> {
  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Poslouchá změny v autentizaci
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      setState(() {}); // Aktualizuje stav aplikace při změně autentizace
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaffAlert',
      theme: ThemeData(
        fontFamily: 'Raleway',
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Color.fromARGB(255, 226, 209, 197),
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? AuthScreen()
          : MainScreen(), // Pokud není přihlášen, zobrazí AuthScreen, jinak MainScreen
      routes: {
        '/settings': (context) => SettingsScreen(),
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
        children: [
          TimerScreen(),    // Hlavní obrazovka s časovačem
          DashboardScreen(), // Dashboard obrazovka
          SettingsScreen(),  // Nastavení
        ],
      ),
    );
  }
}
