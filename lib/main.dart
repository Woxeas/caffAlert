import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'timer_provider.dart';
import 'coffee_stats_provider.dart';
import 'timer_screen.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'name_screen.dart';

// Tyto konstanty budou načteny z proměnných předaných pomocí --dart-define
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace Supabase s využitím build-time konstant
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
    // Poslouchá změny v autentizaci a znovu vyvolá build
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
          ? AuthScreen()
          : const HomeSelector(),
      routes: {
        '/settings': (context) => SettingsScreen(),
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

    // maybeSingle() vrací Map nebo null, pokud záznam neexistuje.
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return false;

    // response je již mapa (PostgrestMap), kterou můžeme použít přímo
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
          return hasName ? MainScreen() : NameScreen();
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
        children: [
          TimerScreen(),    // Hlavní obrazovka s časovačem
          DashboardScreen(), // Dashboard obrazovka
          SettingsScreen(),  // Nastavení
        ],
      ),
    );
  }
}
