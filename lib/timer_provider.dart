import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 60; // Celková doba odpočtu (60 sekund)
  
  // Čas, kdy byla naposledy vložena káva (v UTC)
  DateTime? _lastLogTime;

  // Getter, který dynamicky počítá zbývající čas
  int get remainingTime {
    if (_lastLogTime == null) return durationSeconds;
    final elapsed = DateTime.now().toUtc().difference(_lastLogTime!).inSeconds;
    return max(0, durationSeconds - elapsed);
  }

  Timer? _timer;
  RealtimeChannel? _channel;

  TimerProvider() {
    _initializeTimer();
    _subscribeToCoffeeLogs();
    _startNotifier();
  }

  /// Periodicky (každou sekundu) zavolá notifyListeners(), aby se UI aktualizovalo.
  void _startNotifier() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  /// Načte poslední záznam z DB a uloží jeho čas do _lastLogTime.
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

    if (response != null &&
        response is Map<String, dynamic> &&
        response['created_at'] != null) {
      _lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
    } else {
      // Pokud není žádný záznam, nastavíme _lastLogTime tak, aby elapsed byl >= durationSeconds
      _lastLogTime = DateTime.now().toUtc().subtract(const Duration(seconds: durationSeconds));
    }
    notifyListeners();
  }

  /// Realtime subscription: když se vloží nový záznam (INSERT) do tabulky coffee_logs pro aktuálního uživatele,
  /// realtime callback načte nový poslední záznam a aktualizuje _lastLogTime.
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
            print("Realtime event received: $payload");
            // Po INSERTu načteme poslední záznam z DB a aktualizujeme _lastLogTime
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
            } else {
              _lastLogTime = DateTime.now().toUtc();
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
      await Supabase.instance.client
          .from('coffee_logs')
          .insert({
            'user_id': user.id,
            'created_at': now.toIso8601String(),
          })
          .select();
      // Po vložení nového logu realtime subscription aktualizuje _lastLogTime.
    } catch (e) {
      print("Error inserting coffee log: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
