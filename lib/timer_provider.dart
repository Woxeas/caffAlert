import 'package:flutter/material.dart';
import 'dart:async';

class TimerProvider extends ChangeNotifier {
  static const int initialTime = 60; // Nastav počet sekund (např. 60 nebo 14400 pro 4 hodiny)
  int _remainingTime = 0;
  Timer? _timer;

  int get remainingTime => _remainingTime;

  // Tato funkce spustí časovač od počáteční hodnoty
  void startTimer() {
    _remainingTime = initialTime;
    _timer?.cancel(); // Zruší aktuální timer, pokud existuje

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
        notifyListeners(); // Upozorní UI na změnu stavu
      } else {
        timer.cancel();
      }
    });

    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _remainingTime = initialTime;
    startTimer(); // Znovu spustí timer s původní hodnotou
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
