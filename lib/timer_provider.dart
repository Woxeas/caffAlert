import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

class TimerProvider extends ChangeNotifier {
  static const int durationSeconds = 14400;

  DateTime? _lastLogTime;

  int get remainingTime {
    if (_lastLogTime == null) return durationSeconds;
    final elapsed = DateTime.now().toUtc().difference(_lastLogTime!).inSeconds;
    return max(0, durationSeconds - elapsed);
  }

  Timer? _notifierTimer;
  RealtimeChannel? _channel;

  TimerProvider() {
    _initializeTimer();
    _subscribeToUsersInfoChanges();
    _startNotifier();
  }

  void _startNotifier() {
    _notifierTimer?.cancel();
    _notifierTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  Future<void> _initializeTimer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users_info')
          .select('last_coffee')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response is Map<String, dynamic> && response['last_coffee'] != null) {
        _lastLogTime = DateTime.parse(response['last_coffee'] as String).toUtc();
      } else {
        _lastLogTime = DateTime.now().toUtc().subtract(
            const Duration(seconds: durationSeconds));
      }
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při načítání users_info", e, stackTrace);
    }
    notifyListeners();
  }

  void _subscribeToUsersInfoChanges() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      _channel = Supabase.instance.client
          .channel('public:users_info_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users_info',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload, [ref]) async {
              try {
                final resp = await Supabase.instance.client
                    .from('users_info')
                    .select('last_coffee')
                    .eq('user_id', user.id)
                    .maybeSingle();

                if (resp is Map<String, dynamic> && resp['last_coffee'] != null) {
                  _lastLogTime = DateTime.parse(resp['last_coffee'] as String).toUtc();
                } else {
                  _lastLogTime = DateTime.now().toUtc();
                }
              } catch (e, stackTrace) {
                AppLogger.logger.e("Chyba při načítání realtime last_coffee", e, stackTrace);
              }
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při nastavování realtime subscription", e, stackTrace);
    }
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

      await Supabase.instance.client
          .from('users_info')
          .update({'last_coffee': now.toIso8601String()})
          .eq('user_id', user.id)
          .select();

      _lastLogTime = now;
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e("Chyba při update users_info nebo insertu do coffee_logs", e, stackTrace);
    }
  }

  @override
  void dispose() {
    _notifierTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}