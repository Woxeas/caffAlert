import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      notifyListeners();
        } catch (e) {
      print('Chyba při načítání coffee_logs: $e');
    }
  }

  /// Přidá záznam kávy do Supabase.
  Future<void> addCoffee() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
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
          
      // Pokud insert proběhne úspěšně, aktualizujeme lokální seznam
      coffeeLog.insert(0, now);
      notifyListeners();
    } catch (e) {
      print('Chyba při insertu coffee_logs: $e');
      return;
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
    } catch (e) {
      print('Chyba při mazání dnešních záznamů: $e');
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
    } catch (e) {
      print('Chyba při vkládání nových záznamů: $e');
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
