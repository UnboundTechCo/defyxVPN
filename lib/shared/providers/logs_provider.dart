import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoggerStatus { loading, connecting, switching_method }

class LoggerState {
  final LoggerStatus status;

  const LoggerState({this.status = LoggerStatus.loading});

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

  void setLoading() {
    state = LoggerState(status: LoggerStatus.loading);
  }

  void setConnecting() {
    state = LoggerState(status: LoggerStatus.connecting);
  }

  void setSwitchingMethod() {
    state = LoggerState(status: LoggerStatus.switching_method);
  }
}
