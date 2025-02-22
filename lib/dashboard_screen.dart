import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'coffee_stats_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Formátuje [DateTime] do "HH:mm:ss".
  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt.toLocal());
  }

  /// Vrátí první kávu dneška (nejstarší log pro daný den) nebo null.
  DateTime? _firstCoffee(List<DateTime> logs) {
    final now = DateTime.now();
    final todays = logs.where((dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day);
    if (todays.isEmpty) return null;
    return todays.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Vrátí poslední kávu dneška (nejnovější log) nebo null.
  DateTime? _lastCoffee(List<DateTime> logs) {
    final now = DateTime.now();
    final todays = logs.where((dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day);
    if (todays.isEmpty) return null;
    return todays.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Vypočítá průměrný interval mezi kávami dneška (v minutách).
  String _avgInterval(List<DateTime> logs) {
    final now = DateTime.now();
    final todays = logs.where((dt) =>
        dt.year == now.year && dt.month == now.month && dt.day == now.day).toList();
    if (todays.length < 2) return 'N/A';
    todays.sort((a, b) => a.compareTo(b));
    int totalDiff = 0;
    for (int i = 1; i < todays.length; i++) {
      totalDiff += todays[i].difference(todays[i - 1]).inSeconds.abs();
    }
    final avgSeconds = totalDiff / (todays.length - 1);
    return '${(avgSeconds / 60).toStringAsFixed(1)} min';
  }

  /// Vypočítá průměrný čas první kávy ze všech dní (ve formátu HH:mm).
  String _avgFirstCoffeeTime(List<DateTime> logs) {
    // Rozdělíme logy do skupin podle dne.
    Map<String, DateTime> firstLogs = {};
    for (var dt in logs) {
      final dayKey = DateFormat('yyyy-MM-dd').format(dt.toLocal());
      if (!firstLogs.containsKey(dayKey) || dt.isBefore(firstLogs[dayKey]!)) {
        firstLogs[dayKey] = dt;
      }
    }
    if (firstLogs.isEmpty) return 'N/A';
    // Převod každého času na minuty od půlnoci.
    List<int> minutesList = [];
    for (var dt in firstLogs.values) {
      minutesList.add(dt.toLocal().hour * 60 + dt.toLocal().minute);
    }
    final totalMinutes = minutesList.reduce((a, b) => a + b);
    final avgMinutes = totalMinutes / minutesList.length;
    final avgHour = avgMinutes ~/ 60;
    final avgMin = (avgMinutes % 60).round();
    return '${avgHour.toString().padLeft(2, '0')}:${avgMin.toString().padLeft(2, '0')}';
  }

  /// Zobrazí dialog pro potvrzení odstranění poslední coffee log.
  void _showRemoveLastDialog(BuildContext context, CoffeeStatsProvider statsProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Remove Last Coffee"),
          content: const Text(
              "Are you sure you want to remove the last coffee log? This will update all statistics and the timer on all devices."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await statsProvider.removeLastCoffee();
                Navigator.of(context).pop();
              },
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final coffeeStats = Provider.of<CoffeeStatsProvider>(context);
    final lastCoffee = _lastCoffee(coffeeStats.coffeeLog);
    final firstCoffee = _firstCoffee(coffeeStats.coffeeLog);
    final avgFirstCoffeeTime = _avgFirstCoffeeTime(coffeeStats.coffeeLog);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Karta s informací o poslední kávě
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.local_cafe),
                title: const Text('Last Coffee Today'),
                subtitle: Text(lastCoffee != null
                    ? _formatTime(lastCoffee)
                    : "No coffee logged"),
              ),
            ),
            // Karta s informací o první kávě dneška
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.free_breakfast),
                title: const Text('First Coffee Today'),
                subtitle: Text(firstCoffee != null
                    ? _formatTime(firstCoffee)
                    : "No coffee logged"),
              ),
            ),
            // Karta s průměrným časem první kávy napříč dny
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.av_timer),
                title: const Text('Avg First Coffee Time'),
                subtitle: Text(avgFirstCoffeeTime),
              ),
            ),
            const SizedBox(height: 16),
            // Základní statistiky
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Coffees Today'),
                trailing: Text(
                  "${coffeeStats.dailyCoffees}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Coffees This Month'),
                trailing: Text(
                  "${coffeeStats.monthlyCoffees}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.all_inbox),
                title: const Text('Total Coffees'),
                trailing: Text(
                  "${coffeeStats.totalCoffees}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.av_timer),
                title: const Text('Avg Interval Today'),
                subtitle: Text(_avgInterval(coffeeStats.coffeeLog)),
              ),
            ),
            const SizedBox(height: 16),
            // Tlačítko pro odstranění poslední kávy
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text("Remove Last Coffee"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(300, 50),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => _showRemoveLastDialog(context, coffeeStats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
