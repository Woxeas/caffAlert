import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

class CoffeeStatsProvider extends ChangeNotifier {
  // Lokální seznam pro dočasné uložení (pouze v RAM)
  // Bude se plnit daty z tabulky coffee_logs.
  List<DateTime> coffeeLog = [];

  CoffeeStatsProvider() {
    _loadStatsFromSupabase();
  }

  /// Načte data z Supabase pro aktuálního uživatele.
  Future<void> _loadStatsFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      coffeeLog = [];
      notifyListeners();
      AppLogger.logger.w("No authenticated user found. Not loading coffee logs.");
      return;
    }

    try {
      // Výsledek dotazu je přímo List (PostgrestList)
      final response = await Supabase.instance.client
          .from('coffee_logs')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
          
      final data = response as List<dynamic>;
      coffeeLog = data.map((row) {
        // Předpokládáme, že row['created_at'] je String
        return DateTime.parse(row['created_at'] as String);
      }).toList();
      AppLogger.logger.i("Loaded ${coffeeLog.length} coffee log(s) from Supabase.");
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e("Error loading coffee_logs", e, stackTrace);
    }
  }

  /// Přidá záznam kávy do Supabase.
  Future<void> addCoffee() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppLogger.logger.w("Cannot add coffee log: no authenticated user.");
      return;
    }

    final now = DateTime.now();
    try {
      // Vložíme nový záznam do DB (user_id, created_at)
      await Supabase.instance.client
          .from('coffee_logs')
          .insert({
            'user_id': user.id,
            'created_at': now.toIso8601String(),
          })
          .select();
      AppLogger.logger.i("New coffee log added at $now for user ${user.id}");
      // Aktualizujeme lokální seznam
      coffeeLog.insert(0, now);
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.logger.e("Error inserting coffee_logs", e, stackTrace);
    }
  }

  /// Počet káv za dnešní den
  int get dailyCoffees {
    final now = DateTime.now();
    return coffeeLog.where((date) {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).length;
  }

  /// Počet káv za aktuální měsíc
  int get monthlyCoffees {
    final now = DateTime.now();
    return coffeeLog.where((date) {
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  /// Celkový počet káv (všechny záznamy v coffeeLog)
  int get totalCoffees => coffeeLog.length;

  /// Nastaví počet káv pro dnešní den
  Future<void> setDailyCount(int count) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppLogger.logger.w("Cannot set daily count: no authenticated user.");
      return;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      // Smaž všechny záznamy pro dnešní den v DB
      await Supabase.instance.client
          .from('coffee_logs')
          .delete()
          .eq('user_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String())
          .select();
      AppLogger.logger.i("Deleted coffee logs for today for user ${user.id}");
    } catch (e, stackTrace) {
      AppLogger.logger.e("Error deleting today's coffee logs", e, stackTrace);
      return;
    }

    // Vytvoříme pole nových záznamů
    final List<Map<String, dynamic>> inserts = [];
    for (int i = 0; i < count; i++) {
      inserts.add({
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    try {
      await Supabase.instance.client
          .from('coffee_logs')
          .insert(inserts)
          .select();
      AppLogger.logger.i("Inserted $count new coffee log(s) for user ${user.id}");
    } catch (e, stackTrace) {
      AppLogger.logger.e("Error inserting new coffee logs", e, stackTrace);
      return;
    }

    // Aktualizace lokálního seznamu
    coffeeLog.removeWhere((date) {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    });
    for (int i = 0; i < count; i++) {
      coffeeLog.insert(0, DateTime.now());
    }
    notifyListeners();
  }
}
