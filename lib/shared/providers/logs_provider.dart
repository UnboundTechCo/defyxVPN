import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoggerStatus { loading, connecting, switching_method }

class LoggerState {
  final LoggerStatus status;

  const LoggerState({this.status = LoggerStatus.loading});

  LoggerState copyWith({LoggerStatus? status}) {
    return LoggerState(status: status ?? this.status);
  }
}

final loggerStateProvider = NotifierProvider<LoggerStateNotifier, LoggerState>(
  LoggerStateNotifier.new,
);

class LoggerStateNotifier extends Notifier<LoggerState> {
  @override
  LoggerState build() => const LoggerState();

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
