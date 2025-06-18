import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoggerStatus { scanning, connecting, change_method }

class LoggerState {
  final LoggerStatus status;

  const LoggerState({this.status = LoggerStatus.scanning});

  LoggerState copyWith({LoggerStatus? status}) {
    return LoggerState(status: status ?? this.status);
  }
}

final loggerStateProvider =
    StateNotifierProvider<LoggerStateNotifier, LoggerState>((ref) {
      return LoggerStateNotifier();
    });

class LoggerStateNotifier extends StateNotifier<LoggerState> {
  LoggerStateNotifier() : super(const LoggerState());

  void setScanning() {
    state = LoggerState(status: LoggerStatus.scanning);
  }

  void setConnecting() {
    state = LoggerState(status: LoggerStatus.connecting);
  }

  void setChangeMethod() {
    state = LoggerState(status: LoggerStatus.change_method);
  }
}
