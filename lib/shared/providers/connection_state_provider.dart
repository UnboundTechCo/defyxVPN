import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';

enum ConnectionStatus {
  disconnected,
  loading,
  connected,
  analyzing,
  error,
  noInternet,
}

// Extension to convert ConnectionStatus to int for storage
extension ConnectionStatusExtension on ConnectionStatus {
  int toInt() {
    return index;
  }

  static ConnectionStatus fromInt(int value) {
    return ConnectionStatus.values[value];
  }
}

class ConnectionState {
  final ConnectionStatus status;

  const ConnectionState({this.status = ConnectionStatus.disconnected});

  ConnectionState copyWith({ConnectionStatus? status}) {
    return ConnectionState(status: status ?? this.status);
  }
}

final connectionStateProvider =
    StateNotifierProvider<ConnectionStateNotifier, ConnectionState>((ref) {
      return ConnectionStateNotifier();
    });

class ConnectionStateNotifier extends StateNotifier<ConnectionState> {
  static const String _connectionStatusKey = 'connection_status';

  ConnectionStateNotifier() : super(const ConnectionState());

  // Save the current connection state to SharedPreferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_connectionStatusKey, state.status.toInt());
      print('Saved connection state: ${state.status}');
    } catch (e) {
      print('Error saving connection state: $e');
    }
  }

  void setLoading() {
    state = state.copyWith(status: ConnectionStatus.loading);
    _saveState();
  }

  void setConnected() {
    state = state.copyWith(status: ConnectionStatus.connected);
    _saveState();
  }

  void setDisconnected() {
    state = state.copyWith(status: ConnectionStatus.disconnected);
    _saveState();
  }

  void setError() {
    state = state.copyWith(status: ConnectionStatus.error);
    _saveState();
  }

  void setNoInternet() {
    state = state.copyWith(status: ConnectionStatus.noInternet);
    _saveState();
  }

  void setAnalyzing() {
    state = state.copyWith(status: ConnectionStatus.analyzing);
    _saveState();
  }


}
