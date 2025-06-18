import 'dart:async';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// A dummy implementation of the WarpPlus connection functionality.
class WarpPlus {
  // Connection status codes
  static const int successCode = 100;
  static const int failedToRunWarpCode = 101;
  static const int connectionTestFailedCode = 102;
  static const int networkUnreachableCode = 103;
  static const int logFetchingErrorCode = 104;
  static const int timeoutErrorCode = 105;
  static const int platformExceptionCode = 106;
  static const int unexpectedErrorCode = 107;
  static const int canceledByUserCode = 108;
  static const int pingErrorCode = 109;

  static String global_logs = '[Defyx] Dummy implementation initialized.\n';
  static Timer? _connectionTimer;

  /// Displays a toast message to the user.
  static void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// Simulates a connection with the provided configuration.
  static Future<int> connect(
    WidgetRef ref,
    Map<String, dynamic> config,
    int index,
  ) async {
    global_logs += "[DEBUG] Simulating connection...\n";
    
    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Always succeed in dummy implementation
    _startSimulatedConnection();
    return successCode;
  }

  /// Simulates starting the connection by updating logs periodically
  static void _startSimulatedConnection() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      global_logs += "[INFO] Connection stable - ${DateTime.now()}\n";
    });
  }

  /// Get all accumulated logs.
  static Future<String> getWarpLogs() async {
    return global_logs;
  }

  /// Get only new logs.
  static Future<String> getNewLogs() async {
    return "[INFO] Connection running normally\n";
  }

  /// Clear the logs.
  static void clearWarpLogs({bool clearUILogs = true}) {
    if (clearUILogs) {
      global_logs = "[Defyx] Logs cleared.\n";
    } else {
      global_logs += "\n==== NEW SESSION ====\n";
    }
  }

  /// Simulates stopping the connection.
  static Future<void> stopWarp() async {
    _connectionTimer?.cancel();
    global_logs += "[DEBUG] Connection stopped\n";
  }

  /// Disconnects the dummy connection.
  static Future<void> disconnect() async {
    _connectionTimer?.cancel();
    global_logs += "[DEBUG] Disconnected\n";
  }

  /// Simulates ping measurement.
  static Future<String> getPing() async {
    // Return random ping between 50-150ms
    return (50 + DateTime.now().millisecond % 100).toString();
  }

  /// Returns a dummy flag.
  static Future<String> getFlag() async {
    // Return random country from common VPN locations
    const countries = ['us', 'gb', 'de', 'jp', 'sg'];
    return countries[DateTime.now().second % countries.length];
  }

  /// Simulates network check.
  static Future<bool> checkNetwork() async {
    return true;
  }

  static Timer? _logCleanupTimer;
  static void fetchLogsForMemoryCleanup(WidgetRef ref) {
    _logCleanupTimer?.cancel();
  }

  static void cancelLogCleanupTimer() {
    _logCleanupTimer?.cancel();
  }
}
