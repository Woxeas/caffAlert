import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 60; // Celková doba odpočtu (1 minuta)
  
  DateTime? _lastLogTime;  // Čas posledního logu (v UTC)
  
  // Vypočítaný zbývající čas (nikdy více než 60, nikdy méně než 0)
  int get remainingTime {
    if (_lastLogTime == null) return durationSeconds; // pokud není žádný log, ber 60
    final elapsed = DateTime.now().toUtc().difference(_lastLogTime!).inSeconds;
    return max(0, durationSeconds - elapsed);
  }

  Timer? _notifierTimer;
  RealtimeChannel? _channel;

  TimerProvider() {
    _initializeTimer();
    _subscribeToCoffeeLogs();
    _startNotifier();
  }

  /// Každou sekundu zavolá notifyListeners(), aby se UI obnovilo.
  void _startNotifier() {
    _notifierTimer?.cancel();
    _notifierTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners(); // Každou sekundu se přepočte remainingTime
    });
  }

  /// Načte poslední coffee log z DB a uloží do _lastLogTime.
  Future<void> _initializeTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('coffee_logs')
        .select('created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response is Map<String, dynamic> && response['created_at'] != null) {
      _lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
      print("Poslední log načten: $_lastLogTime");
    } else {
      // Pokud není žádný záznam, ber to, jako by uplynulo >= 60s → timer = 0
      _lastLogTime = DateTime.now().toUtc().subtract(const Duration(seconds: durationSeconds));
      print("Žádný log, nastavujeme _lastLogTime: $_lastLogTime");
    }
    notifyListeners();
  }

  /// Realtime subscription na INSERT v tabulce coffee_logs (user_id = aktuální uživatel).
  void _subscribeToCoffeeLogs() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('public:coffee_logs_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'coffee_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload, [ref]) async {
            print("Realtime event: $payload");
            // Po INSERTu znovu načti poslední log:
            final resp = await Supabase.instance.client
                .from('coffee_logs')
                .select('created_at')
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (resp is Map<String, dynamic> && resp['created_at'] != null) {
              _lastLogTime = DateTime.parse(resp['created_at'] as String).toUtc();
              print("Realtime: nové _lastLogTime: $_lastLogTime");
            } else {
              // fallback: nastavit na aktuální čas
              _lastLogTime = DateTime.now().toUtc();
            }
            notifyListeners();
          },
        )
        .subscribe((status, [extra]) {
          print("Realtime subscription status: $status, extra: $extra");
        });
  }

  Future<void> resetTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();
    try {
      await Supabase.instance.client
          .from('coffee_logs')
          .insert({
            'user_id': user.id,
            'created_at': now.toIso8601String(),
          })
          .select();
      print("Nový coffee log vložen: $now");
      
      // 1) Okamžitě lokálně nastavíme _lastLogTime, abychom měli ihned 60 s
      _lastLogTime = now;
      notifyListeners();

      // 2) Realtime subscription se postará o OSTATNÍ zařízení
      //    Tady nepotřebujeme nic, callback se spustí i na stejném zařízení,
      //    ale klidně až po chvilce – my jsme to vyřešili už teď lokálně.
    } catch (e) {
      print("Chyba při insertu coffee logu: $e");
    }
  }


  @override
  void dispose() {
    _notifierTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
