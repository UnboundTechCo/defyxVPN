import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// File-based error log for Windows/Linux, where Crashlytics is unavailable
/// and `debugPrint` is silenced in release builds.
class DesktopErrorLogger {
  DesktopErrorLogger._internal();
  static final DesktopErrorLogger _instance = DesktopErrorLogger._internal();
  factory DesktopErrorLogger() => _instance;

  static const int _maxLogSizeBytes = 1024 * 1024; // 1MB

  bool get isSupported => Platform.isWindows || Platform.isLinux;

  Future<void> logError(
    String context,
    Object error, [
    StackTrace? stack,
  ]) async {
    if (!isSupported) return;

    try {
      final file = await _logFile();
      final entry =
          '[${DateTime.now().toIso8601String()}] $context: $error\n${stack ?? ''}\n';
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
      await _rotateIfNeeded(file);
    } catch (e) {
      debugPrint('DesktopErrorLogger failed to write log: $e');
    }
  }

  Future<File> _logFile() async {
    final dir = await getApplicationSupportDirectory();
    final logsDir = Directory('${dir.path}${Platform.pathSeparator}logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return File('${logsDir.path}${Platform.pathSeparator}startup.log');
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (await file.length() <= _maxLogSizeBytes) return;
    // Keep only the tail of the log to bound its size.
    final content = await file.readAsString();
    await file.writeAsString(content.substring(content.length ~/ 2));
  }
}
