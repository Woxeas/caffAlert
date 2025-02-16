import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// LogOutput, která zapisuje logy do souboru pro mobil/desktop.
class FileLogOutput extends LogOutput {
  late final File logFile;
  final Completer _initCompleter = Completer();

  FileLogOutput() {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      _initCompleter.complete();
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    logFile = File('${directory.path}/app_logs.txt');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }
    _initCompleter.complete();
  }

  @override
  void output(OutputEvent event) async {
    await _initCompleter.future;
    if (kIsWeb) return;
    final logLine = '${event.lines.join('\n')}\n';
    await logFile.writeAsString(logLine, mode: FileMode.append, flush: true);
  }
}

/// LogOutput pro web, která neukládá nic lokálně.
class _NoOpLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Nic nedělá – nezapisuje do souboru, ani nevolá print().
  }
}
