import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'composite_log_output.dart';
import 'file_log_output.dart';

class AppLogger {
  static final Logger logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: PrettyPrinter(
      methodCount: 2,
      printTime: true,
      colors: !kReleaseMode,
    ),
    output: kIsWeb 
        ? SentryOnlyLogOutput()
        : CompositeLogOutput(FileLogOutput()),
  );
}
