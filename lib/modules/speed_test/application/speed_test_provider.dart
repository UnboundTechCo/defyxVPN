import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speed_test_client.dart';
import 'services/bandwidth_measurement_service.dart';
import 'services/latency_measurement_service.dart';
import 'services/results_calculator_service.dart';
import 'services/speed_measurement_config.dart';
import 'services/speed_test_samples.dart';

enum SpeedTestErrorType { testFailed, connectionUnstable }

class SpeedTestState {
  final SpeedTestStep step;
  final SpeedTestResult result;
  final bool isConnectionStable;
  final SpeedTestErrorType? errorType;

  /// Smoothed live speed of the running direction, in Mbps.
  final double currentSpeed;
  final bool hadError;
  final bool testCompleted;

  const SpeedTestState({
    this.step = SpeedTestStep.ready,
    this.result = const SpeedTestResult(),
    this.isConnectionStable = true,
    this.errorType,
    this.currentSpeed = 0.0,
    this.hadError = false,
    this.testCompleted = false,
  });

  SpeedTestState copyWith({
    SpeedTestStep? step,
    SpeedTestResult? result,
    bool? isConnectionStable,
    SpeedTestErrorType? errorType,
    bool clearErrorMessage = false,
    double? currentSpeed,
    bool? hadError,
    bool? testCompleted,
  }) {
    return SpeedTestState(
      step: step ?? this.step,
      result: result ?? this.result,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
      errorType: clearErrorMessage ? null : (errorType ?? this.errorType),
      currentSpeed: currentSpeed ?? this.currentSpeed,
      hadError: hadError ?? this.hadError,
      testCompleted: testCompleted ?? this.testCompleted,
    );
  }
}

final speedTestProvider =
    StateNotifierProvider<SpeedTestNotifier, SpeedTestState>(
      (ref) => SpeedTestNotifier(ref),
    );

/// One speed test run. Cancelling it aborts its requests, and a cancelled run
/// never writes to the state again, so a stopped run can't leak values into
/// the next one.
class _TestRun {
  final CancelToken cancelToken = CancelToken();
  final SpeedTestSamples samples = SpeedTestSamples();
  final String measurementId =
      (Random().nextDouble() * 1e16).round().toString();

  bool get isCancelled => cancelToken.isCancelled;

  void cancel() {
    if (!isCancelled) cancelToken.cancel();
  }
}

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  SpeedTestNotifier(this._ref) : super(const SpeedTestState()) {
    _alertService.init();
  }

  final Ref _ref;
  final AlertService _alertService = AlertService();
  final Stopwatch _liveUpdateClock = Stopwatch();
  _TestRun? _run;
  ProviderSubscription<ConnectionState>? _connectionSubscription;

  @override
  void dispose() {
    _cancelRun();
    _stopConnectionMonitoring();
    super.dispose();
  }

  void stopAndResetTest() {
    _cancelRun();
    _stopConnectionMonitoring();
    state = const SpeedTestState();
    debugPrint('Speed test stopped and reset');
  }

  Future<void> startTest() async {
    _cancelRun();
    final run = _TestRun();
    _run = run;
    debugPrint('Cloudflare speed test started');

    state = const SpeedTestState(step: SpeedTestStep.loading);
    _startConnectionMonitoring();

    SpeedTestClient? client;
    try {
      client = await SpeedTestClient.create(
        cancelToken: run.cancelToken,
        routeThroughVpnProxy: _shouldUseVpnProxy(),
      );
      await _runMeasurements(run, client);
      if (run.isCancelled) return;

      _stopConnectionMonitoring();
      final result = _finish(run);

      final loggingClient = client;
      client = null;
      unawaited(
        loggingClient
            .logResults(_logData(run, result))
            .whenComplete(loggingClient.close),
      );
    } catch (e) {
      if (run.isCancelled) return;
      debugPrint('Speed test error: $e');
      _alertService.error();
      state = state.copyWith(
        errorType: SpeedTestErrorType.testFailed,
        step: SpeedTestStep.ready,
        isConnectionStable: false,
        currentSpeed: 0.0,
        hadError: true,
      );
    } finally {
      client?.close();
      if (identical(_run, run)) _stopConnectionMonitoring();
    }
  }

  void completeTest() {
    state = state.copyWith(
      step: SpeedTestStep.ready,
      clearErrorMessage: !state.hadError,
      hadError: false,
    );
  }

  void _cancelRun() {
    _run?.cancel();
    _run = null;
  }

  /// Android keeps the app's own traffic outside the tunnel, and Dart's HTTP
  /// client ignores the system proxy used on Windows and Linux. On those
  /// platforms the test only goes through the VPN via the core's local proxy.
  /// On iOS and macOS the packet tunnel already carries the app's traffic.
  bool _shouldUseVpnProxy() {
    final connected =
        _ref.read(connectionStateProvider).status == ConnectionStatus.connected;
    return connected &&
        (Platform.isAndroid || Platform.isWindows || Platform.isLinux);
  }

  void _startConnectionMonitoring() {
    _connectionSubscription?.close();
    _connectionSubscription = _ref.listen<ConnectionState>(
      connectionStateProvider,
      (previous, next) {
        final status = next.status;
        debugPrint('Connection status during test: $status');

        if (!_isConnectionValid(status) && _isTestRunning()) {
          debugPrint('Connection became invalid during speed test, stopping...');
          stopAndResetTest();
        }
      },
    );
  }

  void _stopConnectionMonitoring() {
    _connectionSubscription?.close();
    _connectionSubscription = null;
  }

  bool _isConnectionValid(ConnectionStatus status) {
    return status == ConnectionStatus.disconnected ||
        status == ConnectionStatus.connected;
  }

  bool _isTestRunning() {
    return state.step == SpeedTestStep.loading ||
        state.step == SpeedTestStep.download ||
        state.step == SpeedTestStep.upload;
  }

  Future<void> _runMeasurements(_TestRun run, SpeedTestClient client) async {
    final latency = LatencyMeasurementService(
      client: client,
      measurementId: run.measurementId,
      samples: run.samples,
      isCancelled: () => run.isCancelled,
      onSample: () => _publishResult(run),
    );

    MeasurementType? phase;
    BandwidthMeasurementService? bandwidth;

    for (final step in SpeedMeasurementConfig.measurements) {
      if (run.isCancelled) return;

      if (step.type != phase) {
        if (phase != null) await _endPhase(run, phase);
        if (run.isCancelled) return;

        phase = step.type;
        bandwidth = phase == MeasurementType.latency
            ? null
            : BandwidthMeasurementService(
                type: phase,
                client: client,
                measurementId: run.measurementId,
                samples: run.samples,
                isCancelled: () => run.isCancelled,
                onLiveSpeed: (mbps) => _publishLiveSpeed(run, mbps),
                onSample: () => _publishResult(run),
              );
        _liveUpdateClock
          ..stop()
          ..reset();
        _setState(
          run,
          state.copyWith(step: _stepFor(phase), currentSpeed: 0.0),
        );
      }

      if (bandwidth == null) {
        await latency.run(step);
      } else {
        await bandwidth.run(step);
      }
    }

    if (phase != null && !run.isCancelled) await _endPhase(run, phase);
  }

  /// Shows the final value of a direction for a moment, so the big number
  /// ends on the same value as the result below it.
  Future<void> _endPhase(_TestRun run, MeasurementType phase) async {
    if (phase == MeasurementType.latency) return;
    final result = state.result;
    _setState(
      run,
      state.copyWith(
        currentSpeed: phase == MeasurementType.download
            ? result.downloadSpeed
            : result.uploadSpeed,
      ),
    );
    await Future<void>.delayed(SpeedMeasurementConfig.phaseResultHold);
  }

  static SpeedTestStep _stepFor(MeasurementType type) {
    switch (type) {
      case MeasurementType.latency:
        return SpeedTestStep.loading;
      case MeasurementType.download:
        return SpeedTestStep.download;
      case MeasurementType.upload:
        return SpeedTestStep.upload;
    }
  }

  void _publishResult(_TestRun run) {
    _setState(
      run,
      state.copyWith(result: ResultsCalculatorService.calculate(run.samples)),
    );
  }

  /// Limits live updates to a few per second; the gauge animates in between.
  void _publishLiveSpeed(_TestRun run, double mbps) {
    if (_liveUpdateClock.isRunning &&
        _liveUpdateClock.elapsed < SpeedMeasurementConfig.liveSpeedUiInterval) {
      return;
    }
    _liveUpdateClock
      ..reset()
      ..start();
    _setState(run, state.copyWith(currentSpeed: mbps));
  }

  void _setState(_TestRun run, SpeedTestState next) {
    if (run.isCancelled || !mounted) return;
    state = next;
  }

  SpeedTestResult _finish(_TestRun run) {
    final result = ResultsCalculatorService.calculate(run.samples);
    final stable = ResultsCalculatorService.isStable(result, run.samples);
    debugPrint(
      'Speed test completed: '
      'download ${result.downloadSpeed.toStringAsFixed(2)} Mbps, '
      'upload ${result.uploadSpeed.toStringAsFixed(2)} Mbps, '
      'ping ${result.ping} ms, latency ${result.latency} ms, '
      'jitter ${result.jitter} ms, '
      'failed requests ${run.samples.requestFailures}/${run.samples.requestAttempts}, '
      'stable: $stable',
    );

    if (!stable) _alertService.error();
    state = state.copyWith(
      step: SpeedTestStep.ready,
      result: result,
      currentSpeed: 0.0,
      testCompleted: true,
      isConnectionStable: stable,
      errorType: stable ? null : SpeedTestErrorType.connectionUnstable,
      clearErrorMessage: stable,
      hadError: !stable,
    );
    return result;
  }

  static Map<String, dynamic> _logData(_TestRun run, SpeedTestResult result) => {
    'measId': run.measurementId,
    'downloadMbps': result.downloadSpeed,
    'uploadMbps': result.uploadSpeed,
    'latencyMs': result.latency,
    'jitterMs': result.jitter,
    'packetLossPercent': result.packetLoss,
    'timestamp': DateTime.now().toIso8601String(),
    'client': 'DefyxVPN-Flutter',
  };
}
