import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Kombinovaný LogOutput, který zapisuje do souboru a odesílá chyby do Sentry.
class CompositeLogOutput extends LogOutput {
  final LogOutput fileOutput;

  CompositeLogOutput(this.fileOutput);

  @override
  void output(OutputEvent event) {
    // Zapiš logy do souboru.
    fileOutput.output(event);
    // Pokud jde o chybu nebo vyšší, odešli zprávu do Sentry.
    if (event.level.index >= Level.error.index) {
      // Spustíme captureMessage a výsledek ignorujeme.
      Sentry.captureMessage(event.lines.join('\n'));
    }
  }
}

/// Pro web – jen odesílá chyby do Sentry.
class SentryOnlyLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (event.level.index >= Level.error.index) {
      Sentry.captureMessage(event.lines.join('\n'));
    }
  }
}
