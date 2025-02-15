import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CoffeeStatsProvider extends ChangeNotifier {
  List<String> coffeeLog = [];

  CoffeeStatsProvider() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    coffeeLog = prefs.getStringList('coffeeLog') ?? [];
    notifyListeners();
  }

  Future<void> addCoffee() async {
    String currentTime = DateTime.now().toIso8601String();
    coffeeLog.insert(0, currentTime);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('coffeeLog', coffeeLog);

    notifyListeners();
  }

  int get dailyCoffees {
    DateTime now = DateTime.now();
    return coffeeLog.where((entry) {
      DateTime date = DateTime.parse(entry);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).length;
  }

  int get monthlyCoffees {
    DateTime now = DateTime.now();
    return coffeeLog.where((entry) {
      DateTime date = DateTime.parse(entry);
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  int get totalCoffees => coffeeLog.length;

  Future<void> setDailyCount(int count) async {
    DateTime now = DateTime.now();

    coffeeLog.removeWhere((entry) {
      DateTime date = DateTime.parse(entry);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    });

    for (int i = 0; i < count; i++) {
      coffeeLog.insert(0, DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second).toIso8601String());
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('coffeeLog', coffeeLog);

    notifyListeners();
  }
}
