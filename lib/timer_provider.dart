import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 60; // doba odpočtu v sekundách
  int remainingTime = durationSeconds;
  Timer? _timer;
  RealtimeChannel? _channel;

  TimerProvider() {
    _initializeTimer();
    _subscribeToCoffeeLogs();
  }

  /// Načte poslední záznam z DB a nastaví odpočet.
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

    DateTime lastLogTime;
    if (response != null &&
        response is Map<String, dynamic> &&
        response['created_at'] != null) {
      // Převedeme hodnotu na UTC
      lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
    } else {
      // Pokud není záznam, nastavíme čas tak, aby elapsed byl >= durationSeconds
      lastLogTime = DateTime.now().toUtc().subtract(const Duration(seconds: durationSeconds));
    }
    _startCountdownFrom(lastLogTime);
  }

  /// Spustí odpočet od zadaného času.
  void _startCountdownFrom(DateTime lastLogTime) {
    final nowUtc = DateTime.now().toUtc();
    final elapsed = nowUtc.difference(lastLogTime).inSeconds;
    remainingTime = durationSeconds - elapsed;
    if (remainingTime < 0) remainingTime = 0;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        remainingTime--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// Realtime subscription, která sleduje INSERT události v tabulce coffee_logs.
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
            // Po obdržení INSERTu znovu načteme poslední log z DB:
            final response = await Supabase.instance.client
                .from('coffee_logs')
                .select('created_at')
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            DateTime lastLogTime;
            if (response != null &&
                response is Map<String, dynamic> &&
                response['created_at'] != null) {
              lastLogTime = DateTime.parse(response['created_at'] as String).toUtc();
            } else {
              lastLogTime = DateTime.now().toUtc();
            }
            _startCountdownFrom(lastLogTime);
          },
        )
        .subscribe((RealtimeSubscribeStatus status, [Object? extra]) {
          print("Realtime subscription status: $status, extra: $extra");
        });
  }

  /// Reset timer manuálně (např. při stisknutí tlačítka "I Just Had a Coffee").
  void resetTimer() {
    _startCountdownFrom(DateTime.now().toUtc());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
