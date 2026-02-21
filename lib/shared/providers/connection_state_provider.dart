import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus {
  disconnecting,
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
    NotifierProvider<ConnectionStateNotifier, ConnectionState>(
      ConnectionStateNotifier.new,
    );

class ConnectionStateNotifier extends Notifier<ConnectionState> {
  static const String _connectionStatusKey = 'connection_status';

  // Method channel for receiving events from iOS
  static const EventChannel _eventChannel = EventChannel(
    'com.defyx.vpn_events',
  );

  StreamSubscription? _eventSubscription;

  @override
  ConnectionState build() {
    ref.onDispose(() => _eventSubscription?.cancel());
    // Initialize VPN status listener first, then load saved state
    _initVpnStatusListener();
    return const ConnectionState();
  }

  // Initialize the listener for VPN status events from native side
  Future<void> _initVpnStatusListener() async {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          // Cast to Map<String, dynamic> to work with the event
          final Map<String, dynamic> statusEvent = Map<String, dynamic>.from(
            event,
          );

          // Check if this is a status event
          if (statusEvent.containsKey('status')) {
            final String vpnStatus = statusEvent['status'] as String;
            debugPrint('VPN status update received: $vpnStatus');

            // Always update the UI based on the actual VPN status
            debugPrint('VPN status : $vpnStatus');
            // Update the state based on the VPN status from iOS
            switch (state.status) {
              case ConnectionStatus.analyzing:
                break;
              case ConnectionStatus.error:
                break;
              case ConnectionStatus.noInternet:
                break;
              case ConnectionStatus.connected:
                if (vpnStatus == "disconnected") {
                  debugPrint('VPN status is disconnected from case');
                  setDisconnected();
                }
                break;
              default:
                break;
            }
          }
        }
      },
      onError: (dynamic error) {
        debugPrint('Error from VPN event channel: $error');
        // On error, assume we're disconnected
        setDisconnected();
      },
    );
  }

  // Save the current connection state to SharedPreferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_connectionStatusKey, state.status.toInt());
      debugPrint('Saved connection state: ${state.status}');
    } catch (e) {
      debugPrint('Error saving connection state: $e');
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

  void setDisconnecting() {
    state = state.copyWith(status: ConnectionStatus.disconnecting);
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
