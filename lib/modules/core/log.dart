import 'package:package_info_plus/package_info_plus.dart';

class Log {
  Log._internal();
  static final Log _instance = Log._internal();
  factory Log() => _instance;

  String _logs = "";

  String getLogs() {
    return _logs;
  }

  void clearLogs() {
    _logs = "";
  }

  String addLog(String log) {
    _logs += "\n$log";
    return _logs;
  }

  Future<void> logAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    _logs += '[INFO] App Version: ${info.version}+${info.buildNumber}\n';
  }
}
