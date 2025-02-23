import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'timer_provider.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  String _formatTime(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = context.watch<TimerProvider>(); // ✅ Automatická reaktivita

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 226, 209, 197),
      body: Stack(
        children: [
          // AnimatedContainer pro vizuální vyjádření zbývajícího času
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              height: MediaQuery.of(context).size.height *
                  (timerProvider.remainingTime / TimerProvider.durationSeconds),
              color: const Color.fromARGB(255, 191, 150, 120),
            ),
          ),
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'CaffAlert - Time for Coffee!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Next Coffee In:',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 20),
                Text(
                  _formatTime(timerProvider.remainingTime),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Kliknutím se vloží nový coffee log -> Realtime event -> reset timeru
                    timerProvider.resetTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 50),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'I Just Had a Coffee',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    throw Exception("Testovací chyba z tlačítka");
                  },
                  child: Text("Vyvolat testovací chybu"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}