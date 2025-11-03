import 'dart:async';
import 'dart:math';
import 'package:defyx_vpn/core/network/http_client.dart';
import 'package:defyx_vpn/core/network/http_client_interface.dart';
import 'package:defyx_vpn/modules/speed_test/data/api/speed_test_api.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/vibration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/cloudflare_logger_service.dart';
import 'services/download_measurement_service.dart';
import 'services/latency_measurement_service.dart';
import 'services/results_calculator_service.dart';
import 'services/speed_measurement_config.dart';
import 'services/upload_measurement_service.dart';

class SpeedTestState {
  final SpeedTestStep step;
  final SpeedTestResult result;
  final double progress;
  final bool isConnectionStable;
  final String? errorMessage;
  final String currentPhase;
  final double currentSpeed;
  final bool hadError;
  final bool testCompleted;

  const SpeedTestState({
    this.step = SpeedTestStep.ready,
    this.result = const SpeedTestResult(),
    this.progress = 0.0,
    this.isConnectionStable = true,
    this.errorMessage,
    this.currentPhase = '',
    this.currentSpeed = 0.0,
    this.hadError = false,
    this.testCompleted = false,
  });

  SpeedTestState copyWith({
    SpeedTestStep? step,
    SpeedTestResult? result,
    double? progress,
    bool? isConnectionStable,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? currentPhase,
    double? currentSpeed,
    bool? hadError,
    bool? testCompleted,
  }) {
    return SpeedTestState(
      step: step ?? this.step,
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentPhase: currentPhase ?? this.currentPhase,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      hadError: hadError ?? this.hadError,
      testCompleted: testCompleted ?? this.testCompleted,
    );
  }
}

final speedTestProvider = StateNotifierProvider<SpeedTestNotifier, SpeedTestState>((ref) {
  final httpClient = ref.read(httpClientProvider);
  return SpeedTestNotifier(httpClient, ref);
});

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  final IHttpClient _httpClient;
  final Ref _ref;
  late final SpeedTestApi _api;
  late final CloudflareLoggerService _logger;
  late final VibrationService _vibrationService;

  bool _isTestCanceled = false;
  Timer? _testTimer;
  final List<StreamSubscription> _activeSubscriptions = [];
  ProviderSubscription<ConnectionState>? _connectionSubscription;

  String _measurementId = '';
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];

  SpeedTestNotifier(this._httpClient, this._ref) : super(const SpeedTestState()) {
    final dio = (_httpClient as HttpClient).dio;

    dio.options.connectTimeout = SpeedMeasurementConfig.connectTimeout;
    dio.options.receiveTimeout = SpeedMeasurementConfig.receiveTimeout;
    dio.options.sendTimeout = SpeedMeasurementConfig.sendTimeout;
    dio.options.headers['User-Agent'] = 'Defyx VPN Speed Test';

    _api = SpeedTestApi(dio);
    _logger = CloudflareLoggerService(_api);
    _vibrationService = VibrationService();
    _vibrationService.init();
  }

  String _generateMeasurementId() {
    return (Random().nextDouble() * 1e16).round().toString();
  }

  @override
  void dispose() {
    _stopTestOnly();
    _stopConnectionMonitoring();
    super.dispose();
  }

  void stopAndResetTest() {
    _isTestCanceled = true;
    _testTimer?.cancel();
    _testTimer = null;

    _stopConnectionMonitoring();

    for (final subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();

    state = const SpeedTestState();

    debugPrint('🛑 Speed test stopped and reset');
  }

  void _stopTestOnly() {
    _isTestCanceled = true;
    _testTimer?.cancel();
    _testTimer = null;

    for (final subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();

    debugPrint('🛑 Speed test stopped (without state reset)');
  }

  Future<void> startTest() async {
    if (!_isTestCanceled) {
      stopAndResetTest();
    }

    _isTestCanceled = false;
    debugPrint('🚀 Cloudflare Speed Test Started');
    _measurementId = _generateMeasurementId();

    state = state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      result: const SpeedTestResult(),
      currentPhase: 'Initializing...',
      currentSpeed: 0.0,
      errorMessage: null,
      isConnectionStable: true,
      hadError: false,
    );

    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();

    _startConnectionMonitoring();

    try {
      await _runMeasurementSequence();

      if (_isTestCanceled) {
        debugPrint('🛑 Speed test was canceled');
        _stopConnectionMonitoring();
        return;
      }

      _calculateFinalResults();
      _checkConnectionStability();
      debugPrint('🏁 Speed test completed successfully');
      _stopConnectionMonitoring();
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      _stopConnectionMonitoring();
      _vibrationService.vibrateError();
      state = state.copyWith(
        errorMessage: 'Speed test failed. Please try again.',
        step: SpeedTestStep.ready,
        isConnectionStable: false,
        currentSpeed: 0.0,
        hadError: true,
      );
    }
  }

  void _startConnectionMonitoring() {
    _connectionSubscription?.close();
    _connectionSubscription = _ref.listen<ConnectionState>(
      connectionStateProvider,
      (previous, next) {
        final status = next.status;
        debugPrint('🔍 Connection status during test: $status');

        if (!_isConnectionValid(status) && _isTestRunning()) {
          debugPrint('🛑 Connection became invalid during speed test, stopping...');
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
    return status == ConnectionStatus.disconnected || status == ConnectionStatus.connected;
  }

  bool _isTestRunning() {
    return state.step == SpeedTestStep.loading ||
        state.step == SpeedTestStep.download ||
        state.step == SpeedTestStep.upload;
  }

  Future<void> _runMeasurementSequence() async {
    String currentPhase = '';

    for (int i = 0; i < SpeedMeasurementConfig.measurements.length; i++) {
      if (_isTestCanceled) {
        debugPrint('🛑 Measurement sequence canceled');
        return;
      }

      final measurement = SpeedMeasurementConfig.measurements[i];
      final progress = (i + 1) / SpeedMeasurementConfig.totalMeasurements;
      final type = measurement['type'] as String;

      bool needsPhaseChange = false;
      SpeedTestStep? nextStep;

      if (type == 'latency' && currentPhase != 'loading') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.loading;
        currentPhase = 'loading';
      } else if (type == 'download' && currentPhase != 'download') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.download;
        currentPhase = 'download';
      } else if (type == 'upload' && currentPhase != 'upload') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.upload;
        currentPhase = 'upload';
      }

      if (needsPhaseChange && i > 0 && state.progress > 0) {
        state = state.copyWith(progress: 0.0);
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_isTestCanceled) {
          debugPrint('🛑 Measurement sequence canceled during transition');
          return;
        }
      }

      if (needsPhaseChange && nextStep != null) {
        state = state.copyWith(step: nextStep);
      }

      debugPrint(
          '📊 Running measurement ${i + 1}/${SpeedMeasurementConfig.totalMeasurements}: $type');

      switch (type) {
        case 'latency':
          await _runLatencyMeasurement(measurement);
          break;
        case 'download':
          await _runDownloadMeasurement(measurement, progress);
          break;
        case 'upload':
          await _runUploadMeasurement(measurement, progress);
          break;
      }

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
    }
  }

  Future<void> _runLatencyMeasurement(Map<String, dynamic> config) async {
    final numPackets = config['numPackets'] as int;
    state = state.copyWith(
      step: SpeedTestStep.loading,
      currentPhase: 'Measuring latency... ($numPackets packets)',
    );

    final service = LatencyMeasurementService(
      api: _api,
      measurementId: _measurementId,
      isCanceledCheck: (reset) => _isTestCanceled,
      onMetricsUpdate: (ping, latency, jitter) {
        state = state.copyWith(
          result: state.result.copyWith(
            ping: ping,
            latency: latency,
            jitter: jitter,
          ),
        );
      },
    );

    await service.runMeasurement(config);
    _latencies.addAll(service.latencies);
  }

  Future<void> _runDownloadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);

    state = state.copyWith(
      step: SpeedTestStep.download,
      currentPhase: 'Download test: $sizeLabel',
      progress: progress,
    );

    final service = DownloadMeasurementService(
      api: _api,
      measurementId: _measurementId,
      isCanceledCheck: (reset) => _isTestCanceled,
      onSpeedUpdate: (speed) {
        state = state.copyWith(currentSpeed: speed);
      },
      onMetricsUpdate: (percentileSpeed, avgSpeed, currentPing, avgLatency, jitter) {
        state = state.copyWith(
          currentSpeed: avgSpeed,
          result: state.result.copyWith(
            downloadSpeed: percentileSpeed,
            ping: currentPing,
            latency: avgLatency,
            jitter: jitter,
          ),
        );
      },
      latencies: _latencies,
    );

    await service.runMeasurement(config);
    _downloadSpeeds.addAll(service.downloadSpeeds);
  }

  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);

    state = state.copyWith(
      step: SpeedTestStep.upload,
      currentPhase: 'Upload test: $sizeLabel',
      progress: progress,
    );

    final service = UploadMeasurementService(
      api: _api,
      measurementId: _measurementId,
      isCanceledCheck: (reset) => _isTestCanceled,
      onSpeedUpdate: (speed) {
        state = state.copyWith(currentSpeed: speed);
      },
      onMetricsUpdate: (percentileSpeed, avgSpeed, jitter, packetLoss) {
        state = state.copyWith(
          currentSpeed: avgSpeed,
          result: state.result.copyWith(
            uploadSpeed: percentileSpeed,
            jitter: jitter,
            packetLoss: packetLoss,
          ),
        );
      },
      latencies: _latencies,
      measurements: SpeedMeasurementConfig.measurements,
    );

    await service.runMeasurement(config);
    _uploadSpeeds.addAll(service.uploadSpeeds);
  }

  void _calculateFinalResults() {
    final result = ResultsCalculatorService.calculateFinalResults(
      downloadSpeeds: _downloadSpeeds,
      uploadSpeeds: _uploadSpeeds,
      latencies: _latencies,
      measurements: SpeedMeasurementConfig.measurements,
    );

    state = state.copyWith(
      result: result,
      progress: 1.0,
      currentPhase: 'Test completed',
      testCompleted: true,
    );

    _logger.logResults(
      measurementId: _measurementId,
      result: result,
    );
  }

  void _checkConnectionStability() {
    final isStable = ResultsCalculatorService.checkConnectionStability(state.result);

    if (!isStable) {
      _vibrationService.vibrateError();
      state = state.copyWith(
        step: SpeedTestStep.ready,
        isConnectionStable: false,
        errorMessage: 'Your connection was unstable, and the test was interrupted.',
        hadError: true,
      );
    } else {
      state = state.copyWith(
        step: SpeedTestStep.ready,
        clearErrorMessage: true,
        hadError: false,
      );
    }
  }

  void resetTest() {
    stopAndResetTest();
  }

  void retryConnection() {
    stopAndResetTest();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isTestCanceled) {
        startTest();
      }
    });
  }

  void completeTest() {
    state = state.copyWith(
      step: SpeedTestStep.ready,
      errorMessage: state.hadError ? state.errorMessage : null,
      hadError: false,
    );
  }
}
