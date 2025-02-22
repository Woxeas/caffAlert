import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

class CoffeeStatsProvider extends ChangeNotifier {
  List<DateTime> coffeeLog = [];
  RealtimeChannel? _channel;

  CoffeeStatsProvider() {
    _loadStatsFromSupabase();
    _subscribeToCoffeeLogs();
  }

  Future<void> _loadStatsFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      coffeeLog = [];
      notifyListeners();
      AppLogger.logger.w("No authenticated user found. Not loading coffee logs.");
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('coffee_logs')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      coffeeLog = data.map((row) {
        return DateTime.parse(row['created_at'] as String);
      }).toList();
      AppLogger.logger.i("Loaded ${coffeeLog.length} coffee log(s) from Supabase.");
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e(
        "Error loading coffee_logs",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _subscribeToCoffeeLogs() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppLogger.logger.w("Cannot subscribe to realtime coffee_logs: no authenticated user.");
      return;
    }

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
              AppLogger.logger.i("Realtime INSERT event: $payload");
              await _loadStatsFromSupabase();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'coffee_logs',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload, [ref]) async {
              AppLogger.logger.i("Realtime DELETE event: $payload");
              await _loadStatsFromSupabase();
            },
          )
          .subscribe((status, [extra]) {
            AppLogger.logger.i("Realtime subscription status: $status, extra: $extra");
          });
    } catch (e, stackTrace) {
      AppLogger.logger.e(
        "Error subscribing to realtime coffee_logs",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Přidá nový coffee log do Supabase a aktualizuje lokální seznam.
  Future<void> addCoffee() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppLogger.logger.w("Cannot add coffee log: no authenticated user.");
      return;
    }

    final now = DateTime.now();
    try {
      await Supabase.instance.client
          .from('coffee_logs')
          .insert({
            'user_id': user.id,
            'created_at': now.toIso8601String(),
          })
          .select();
      AppLogger.logger.i("New coffee log added at $now for user ${user.id}");
      coffeeLog.insert(0, now);
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e(
        "Error inserting coffee_logs",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Odstraní poslední vložený coffee log z databáze a aktualizuje lokální seznam.
  Future<void> removeLastCoffee() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppLogger.logger.w("Cannot remove coffee log: no authenticated user.");
      return;
    }

    try {
      // Načteme poslední log (nejnovější) pomocí řazení a limitu 1.
      final response = await Supabase.instance.client
          .from('coffee_logs')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        AppLogger.logger.w("No coffee log found to remove.");
        return;
      }

      final logId = response['id'];
      await Supabase.instance.client
          .from('coffee_logs')
          .delete()
          .eq('id', logId)
          .select();
      AppLogger.logger.i("Removed coffee log with id: $logId");

      if (coffeeLog.isNotEmpty) {
        coffeeLog.removeAt(0);
      }
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e(
        "Error removing last coffee log",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Vrací počet káv za dnešní den.
  int get dailyCoffees {
    final now = DateTime.now();
    return coffeeLog.where((date) =>
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day).length;
  }

  /// Vrací počet káv za aktuální měsíc.
  int get monthlyCoffees {
    final now = DateTime.now();
    return coffeeLog.where((date) =>
        date.year == now.year &&
        date.month == now.month).length;
  }

  /// Vrací celkový počet káv.
  int get totalCoffees => coffeeLog.length;

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
