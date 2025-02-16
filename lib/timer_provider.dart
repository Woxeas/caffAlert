import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 60; // Celková doba odpočtu v sekundách (1 minuta)
  
  // Interní proměnná pro čas posledního logu (v UTC)
  DateTime? _lastLogTime;
  
  // Timer není závislý na _lastLogTime – remainingTime se počítá dynamicky
  int get remainingTime {
    if (_lastLogTime == null) return durationSeconds;
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

  /// Spustí periodické upozorňování (každou sekundu) – tím se UI obnovuje.
  void _startNotifier() {
    _notifierTimer?.cancel();
    _notifierTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  /// Načte poslední záznam z DB a uloží jeho čas do _lastLogTime.
  Future<void> _initializeTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Dotaz: načti poslední záznam (coffee log) pro aktuálního uživatele.
    final response = await Supabase.instance.client
        .from('coffee_logs')
        .select('created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null &&
        response is Map<String, dynamic> &&
        response['created_at'] != null) {
      _lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
      print("Poslední log načten: $_lastLogTime");
    } else {
      // Pokud není žádný záznam, nastavíme _lastLogTime tak, že rozdíl bude >= 60 sekund (timer = 0)
      _lastLogTime = DateTime.now().toUtc().subtract(const Duration(seconds: durationSeconds));
      print("Žádný log nalezen, _lastLogTime nastaveno na: $_lastLogTime");
    }
    notifyListeners();
  }

  /// Realtime subscription: sleduje INSERT události v tabulce coffee_logs pro aktuálního uživatele.
  void _subscribeToCoffeeLogs() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Vytvoříme realtime kanál s unikátním názvem pro daného uživatele.
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
            print("Realtime event received: $payload");
            // Po vložení nového logu dotáhneš z DB poslední log
            final response = await Supabase.instance.client
                .from('coffee_logs')
                .select('created_at')
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (response != null &&
                response is Map<String, dynamic> &&
                response['created_at'] != null) {
              _lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
              print("Realtime: aktualizováno _lastLogTime: $_lastLogTime");
            } else {
              _lastLogTime = DateTime.now().toUtc();
              print("Realtime: žádný log nalezen, _lastLogTime aktualizováno na nyní: $_lastLogTime");
            }
            notifyListeners();
          },
        )
        .subscribe((RealtimeSubscribeStatus status, [Object? extra]) {
          print("Realtime subscription status: $status, extra: $extra");
        });
  }

  /// Reset timer manuálně tím, že vloží nový coffee log do DB.
  Future<void> resetTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();
    try {
      // Vložení nového logu. Pokud tabulka má default pro created_at, nemusíš ho posílat,
      // ale zde jej explicitně předáváme.
      await Supabase.instance.client
          .from('coffee_logs')
          .insert({
            'user_id': user.id,
            'created_at': now.toIso8601String(),
          })
          .select();
      print("Nový coffee log vložen: $now");
      // Realtime subscription by měl přijmout INSERT event a aktualizovat _lastLogTime.
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
