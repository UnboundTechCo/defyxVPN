import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:defyx_vpn/modules/core/warp_plus.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as connection_state;
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';

/// A controller that manages the connection flow process.
class FlowLineController {
  // Constants
  static const _configPath = 'assets/settings/config.json';

  /// Provider for tracking the flow line state (active/inactive)
  static final flowLineStateNotifier = StateProvider<bool>((ref) => false);

  /// Loads the configuration from the config file.
  static Future<Map<String, dynamic>> _loadConfig() async {
    final String configData = await rootBundle.loadString(_configPath);

    final config = jsonDecode(configData);

    return config;
  }

  /// Returns the total number of steps in the flow line configuration.
  static Future<int> getTotalSteps() async {
    final config = await _loadConfig();
    final List<dynamic> flowLine = config['flowLine'];
    final totalSteps = flowLine.length;

    return totalSteps;
  }

  /// Returns the number of enabled steps in the flow line configuration.
  static Future<int> getEnabledStepsCount() async {
    final config = await _loadConfig();
    final List<dynamic> flowLine = config['flowLine'];

    final enabledCount =
        flowLine.where((item) => item['enabled'] == true).length;

    return enabledCount;
  }

  /// Starts the connection process using the configuration.
  ///
  /// Returns a map containing the result of the connection attempt.
  static Future<Map<String, dynamic>?> startFromConfig(WidgetRef ref) async {
    WarpPlus.clearWarpLogs(clearUILogs: true);

    // Initialize connection state
    final connectionNotifier = ref.read(
      connection_state.connectionStateProvider.notifier,
    );

    connectionNotifier.setAnalyzing();

    // Initialize logger state
    final loggerNotifier = ref.read(loggerStateProvider.notifier);

    loggerNotifier.setScanning();

    await Future.delayed(const Duration(milliseconds: 100));

    // Reset and prepare flow line
    final flowLineNotifier = ref.read(flowLineStepProvider.notifier);

    flowLineNotifier.resetStep();

    // Load configuration
    final config = await _loadConfig();
    final List<dynamic> flowLine = config['flowLine'];

    // Determine starting index
    final currentStep = flowLineNotifier.state.step;
    final startIndex = (currentStep < flowLine.length) ? currentStep : 0;

    // Start connection process
    ref.read(flowLineStateNotifier.notifier).state = true;

    // Attempt connection with each enabled configuration
    for (int index = startIndex; index < flowLine.length; index++) {
      // Check if process has been stopped
      if (ref.read(flowLineStateNotifier.notifier).state != true) {
        // User cancelled the connection process
        await WarpPlus.disconnect();
        break;
      }

      // Add a clear step separator for better log readability
      WarpPlus.global_logs += "\n----- STEP ${index + 1} LOGS ------\n";

      final item = flowLine[index];

      loggerNotifier.setScanning();
      await Future.delayed(const Duration(milliseconds: 100));

      // Skip disabled items
      if (item['enabled'] != true) {
        continue;
      }

      // Update current step
      flowLineNotifier.setStep(index);

      // Attempt connection
      final errorCode = await WarpPlus.connect(ref, item, index);

      // Handle connection result
      final handleResult = await _handleErrorCode(
        errorCode,
        connectionNotifier,
        ref,
      );

      if (handleResult == 100) {
        return {
          'success': true,
          'config': item,
          'errorCode': errorCode,
          'index': index,
        };
      }
      if (handleResult == 108) {
        return {
          'success': false,
          'errorCode': errorCode,
          'message': 'Connection cancelled by user',
        };
      }

      if (handleResult == 103) {
        flowLineNotifier.resetStep();
        await WarpPlus.disconnect();
        return {
          'success': false,
          'errorCode': errorCode,
          'message': 'No Internet Connection',
        };
      }

      // Connection failed, try next method
      loggerNotifier.setChangeMethod();
      await Future.delayed(const Duration(seconds: 3));
    }

    // All attempts failed or connection process was stopped
    if (ref.read(flowLineStateNotifier.notifier).state == true) {
      flowLineNotifier.resetStep();
      connectionNotifier.setError();
      await WarpPlus.disconnect();

      return {
        'success': false,
        'errorCode': -1,
        'message': 'All connection attempts failed',
      };
    }

    return null;
  }

  /// Sets the current connection step.
  static void setConnectionStep(WidgetRef ref, int step) {
    ref.read(flowLineStepProvider.notifier).setStep(step);
  }

  /// Gets the current connection step.
  static int getCurrentStep(WidgetRef ref) {
    final currentStep = ref.read(flowLineStepProvider).step;
    return currentStep;
  }

  /// Resets the connection step to the initial state.
  static void resetConnectionStep(WidgetRef ref) {
    ref.read(flowLineStepProvider.notifier).resetStep();
  }

  /// Cancels the current connection attempt.
  static Future<void> cancelConnection() async {
    await WarpPlus.disconnect();
  }

  /// Handles error codes from the connection attempt.
  ///
  /// Returns true if connection was successful, false otherwise.
  static Future<int> _handleErrorCode(
    int code,
    connection_state.ConnectionStateNotifier connectionNotifier,
    WidgetRef ref,
  ) async {
    // Check if the connection process is still active
    final flowLineState = ref.read(flowLineStateNotifier.notifier).state;

    if (flowLineState == true) {
      switch (code) {
        case WarpPlus.successCode:
          // Connection successful
          connectionNotifier.setConnected();
          return 100;
        case WarpPlus.networkUnreachableCode:
          // Internet connectivity issues
          return 103;
        case WarpPlus.canceledByUserCode:
          // User cancelled the connection process
          return 108;
        case WarpPlus.pingErrorCode:
        case WarpPlus.failedToRunWarpCode:
        case WarpPlus.connectionTestFailedCode:
        case WarpPlus.logFetchingErrorCode:
        case WarpPlus.timeoutErrorCode:
        case WarpPlus.platformExceptionCode:
        case WarpPlus.unexpectedErrorCode:
        default:
          // Other errors, try again after short delay
          await WarpPlus.stopWarp();

          await Future.delayed(const Duration(seconds: 2));
          return 111;
      }
    }

    // Connection process was stopped
    await WarpPlus.disconnect();

    return 108;
  }
}
