import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart'; // import našeho centralizovaného loggeru

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 60; // Celková doba odpočtu (1 minuta)

  DateTime? _lastLogTime; // Čas posledního logu (v UTC)

  // Dynamicky počítaný zbývající čas (nikdy více než 60, nikdy méně než 0)
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

  /// Periodicky (každou sekundu) zavolá notifyListeners(), aby se UI aktualizovalo.
  void _startNotifier() {
    _notifierTimer?.cancel();
    _notifierTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners(); // Každou sekundu se přepočítá remainingTime
    });
  }

  /// Načte poslední coffee log z DB a uloží jeho čas do _lastLogTime.
  Future<void> _initializeTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('coffee_logs')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response is Map<String, dynamic> && response['created_at'] != null) {
        _lastLogTime =
            DateTime.parse(response['created_at'] as String).toUtc();
        AppLogger.logger.i("Poslední log načten: $_lastLogTime");
      } else {
        // Pokud není žádný záznam, nastavíme _lastLogTime tak, aby rozdíl byl >= 60s (timer = 0)
        _lastLogTime = DateTime.now().toUtc().subtract(
            const Duration(seconds: durationSeconds));
        AppLogger.logger.i("Žádný log, nastavujeme _lastLogTime: $_lastLogTime");
      }
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při načítání coffee_logs", e, stackTrace);
    }
    notifyListeners();
  }

  /// Realtime subscription: sleduje INSERT události v tabulce coffee_logs pro aktuálního uživatele.
  void _subscribeToCoffeeLogs() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
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
              AppLogger.logger.i("Realtime event: $payload");
              // Po INSERTu znovu načti poslední log:
              try {
                final resp = await Supabase.instance.client
                    .from('coffee_logs')
                    .select('created_at')
                    .eq('user_id', user.id)
                    .order('created_at', ascending: false)
                    .limit(1)
                    .maybeSingle();

                if (resp is Map<String, dynamic> && resp['created_at'] != null) {
                  _lastLogTime =
                      DateTime.parse(resp['created_at'] as String).toUtc();
                  AppLogger.logger.i("Realtime: nové _lastLogTime: $_lastLogTime");
                } else {
                  _lastLogTime = DateTime.now().toUtc();
                  AppLogger.logger.w(
                      "Realtime: žádný log nalezen, _lastLogTime nastaveno na nyní: $_lastLogTime");
                }
              } catch (e, stackTrace) {
                AppLogger.logger.e("Chyba při načítání realtime logu", e, stackTrace);
              }
              notifyListeners();
            },
          )
          .subscribe((status, [extra]) {
            AppLogger.logger.i(
                "Realtime subscription status: $status, extra: $extra");
          });
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při nastavování realtime subscription", e, stackTrace);
    }
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
      AppLogger.logger.i("Nový coffee log vložen: $now");
      // Okamžitě lokálně nastavíme _lastLogTime, abychom měli ihned 60 sekund.
      _lastLogTime = now;
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při insertu coffee logu", e, stackTrace);
    }
  }

  @override
  void dispose() {
    _notifierTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
