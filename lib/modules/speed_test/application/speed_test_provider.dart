import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/http_client_interface.dart';
import '../data/api/speed_test_api.dart';
import '../models/speed_test_result.dart';

class SpeedTestState {
  final SpeedTestStep step;
  final SpeedTestResult result;
  final double progress;
  final bool isConnectionStable;
  final String? errorMessage;
  final String currentPhase;
  final double currentSpeed; // Real-time speed for UI updates

  const SpeedTestState({
    this.step = SpeedTestStep.ready,
    this.result = const SpeedTestResult(),
    this.progress = 0.0,
    this.isConnectionStable = true,
    this.errorMessage,
    this.currentPhase = '',
    this.currentSpeed = 0.0,
  });

  SpeedTestState copyWith({
    SpeedTestStep? step,
    SpeedTestResult? result,
    double? progress,
    bool? isConnectionStable,
    String? errorMessage,
    String? currentPhase,
    double? currentSpeed,
  }) {
    return SpeedTestState(
      step: step ?? this.step,
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPhase: currentPhase ?? this.currentPhase,
      currentSpeed: currentSpeed ?? this.currentSpeed,
    );
  }
}

final speedTestProvider = StateNotifierProvider<SpeedTestNotifier, SpeedTestState>((ref) {
  final httpClient = ref.read(httpClientProvider);
  return SpeedTestNotifier(httpClient);
});

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  final IHttpClient _httpClient;
  late final SpeedTestApi _api;

  // Measurement configuration following Cloudflare's protocol
  // Organized by step: LOADING (latency) → DOWNLOAD → UPLOAD
  static const List<Map<String, dynamic>> _measurements = [
    // LOADING PHASE: Latency measurements
    {'type': 'latency', 'numPackets': 1}, // initial TTFB estimation
    {'type': 'latency', 'numPackets': 20}, // detailed latency measurements

    // DOWNLOAD PHASE: Progressive download tests
    {'type': 'download', 'bytes': 100000, 'count': 1},
    {'type': 'download', 'bytes': 100000, 'count': 9},
    {'type': 'download', 'bytes': 1000000, 'count': 8},
    {'type': 'download', 'bytes': 10000000, 'count': 6},
    {'type': 'download', 'bytes': 25000000, 'count': 4},
    {'type': 'download', 'bytes': 100000000, 'count': 3},
    {'type': 'download', 'bytes': 250000000, 'count': 2},

    // UPLOAD PHASE: Progressive upload tests
    {'type': 'upload', 'bytes': 100000, 'count': 8},
    {'type': 'upload', 'bytes': 1000000, 'count': 6},
    {'type': 'upload', 'bytes': 10000000, 'count': 4},
    {'type': 'upload', 'bytes': 25000000, 'count': 4},
    {'type': 'upload', 'bytes': 50000000, 'count': 3},
  ];

  // Real-time measurement tracking
  String _measurementId = '';
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];

  // Progress tracking
  static const int _totalMeasurements = 14; // Total measurements in our sequence

  SpeedTestNotifier(this._httpClient) : super(const SpeedTestState()) {
    // Get the underlying Dio instance from HttpClient
    final dio = (_httpClient as HttpClient).dio;

    // Configure Dio for speed test with proper timeouts
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 60);
    dio.options.sendTimeout = const Duration(seconds: 60);
    dio.options.headers['User-Agent'] = 'Defyx VPN Speed Test';

    // Create Retrofit API instance
    _api = SpeedTestApi(dio);
  }

  String _generateMeasurementId() {
    return (Random().nextDouble() * 1e16).round().toString();
  }

  Future<void> startTest() async {
    print('🚀 Cloudflare Speed Test Started');
    _measurementId = _generateMeasurementId();

    state = state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      result: const SpeedTestResult(),
      currentPhase: 'Initializing...',
      currentSpeed: 0.0,
      errorMessage: null,
      isConnectionStable: true,
    );

    // Reset all measurement data
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();

    try {
      // Start the measurement sequence
      await _runMeasurementSequence();

      // Calculate final results
      _calculateFinalResults();

      // Check connection stability and move to next step
      _checkConnectionStability();
      print('🏁 Speed test completed successfully');
    } catch (e) {
      print('❌ Speed test error: $e');
      // Show toast state with error, then allow retry
      state = state.copyWith(
        errorMessage: 'Speed test failed. Please try again.',
        step: SpeedTestStep.toast,
        isConnectionStable: false,
        currentSpeed: 0.0,
      );
    }
  }

  Future<void> _runMeasurementSequence() async {
    String currentPhase = '';

    for (int i = 0; i < _measurements.length; i++) {
      final measurement = _measurements[i];
      final progress = (i + 1) / _totalMeasurements;
      final type = measurement['type'] as String;

      // Update step based on measurement type (maintain order: loading → download → upload)
      if (type == 'latency' && currentPhase != 'loading') {
        currentPhase = 'loading';
        state = state.copyWith(step: SpeedTestStep.loading);
      } else if (type == 'download' && currentPhase != 'download') {
        currentPhase = 'download';
        state = state.copyWith(step: SpeedTestStep.download);
      } else if (type == 'upload' && currentPhase != 'upload') {
        currentPhase = 'upload';
        state = state.copyWith(step: SpeedTestStep.upload);
      }

      print('📊 Running measurement ${i + 1}/$_totalMeasurements: $type');

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

      // Small delay between measurements
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _runLatencyMeasurement(Map<String, dynamic> config) async {
    final numPackets = config['numPackets'] as int;
    state = state.copyWith(
      step: SpeedTestStep.loading,
      currentPhase: 'Measuring latency... ($numPackets packets)',
    );

    int consecutiveFailures = 0;
    const maxConsecutiveFailures = 3; // Stop after 3 consecutive failures

    for (int i = 0; i < numPackets; i++) {
      try {
        final startTime = DateTime.now();
        await _api.latencyTest(
          bytes: 0,
          measurementId: _measurementId,
        );
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        _latencies.add(latency);
        consecutiveFailures = 0; // Reset on success

        // Update metrics immediately after each latency measurement
        final avgLatency = _latencies.isNotEmpty
            ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
            : 0;

        // Calculate jitter if we have at least 2 measurements
        int jitter = 0;
        if (_latencies.length >= 2) {
          int jitterSum = 0;
          for (int j = 1; j < _latencies.length; j++) {
            jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
          }
          jitter = (jitterSum / (_latencies.length - 1)).round();
        }

        state = state.copyWith(
          result: state.result.copyWith(
            ping: avgLatency,
            latency: avgLatency,
            jitter: jitter,
          ),
        );

        print(
            '   📡 Latency ${i + 1}/$numPackets: ${latency}ms (Avg: ${avgLatency}ms, Jitter: ${jitter}ms)');
      } catch (e) {
        consecutiveFailures++;
        print('   ❌ Latency measurement ${i + 1} failed: $e');

        // If we have too many consecutive failures, throw to stop the test
        if (consecutiveFailures >= maxConsecutiveFailures) {
          throw Exception('Network connection failed. Please check your internet connection.');
        }
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }

    // If we have no successful measurements at all, throw error
    if (_latencies.isEmpty) {
      throw Exception('Failed to measure latency. Please check your internet connection.');
    }
  }

  Future<void> _runDownloadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = _formatBytes(bytes);

    state = state.copyWith(
      step: SpeedTestStep.download,
      currentPhase: 'Download test: $sizeLabel',
      progress: progress,
    );

    int consecutiveFailures = 0;
    const maxConsecutiveFailures = 3;

    for (int i = 0; i < count; i++) {
      try {
        final speed = await _measureDownloadSpeed(bytes);
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          consecutiveFailures = 0; // Reset on success

          // Calculate current metrics
          final maxSpeed = _downloadSpeeds.reduce((a, b) => a > b ? a : b);
          final avgSpeed = _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;
          final avgLatency = _latencies.isNotEmpty
              ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
              : 0;

          // Calculate jitter
          int jitter = 0;
          if (_latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < _latencies.length; j++) {
              jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (_latencies.length - 1)).round();
          }

          // Update state with current speed and metrics immediately
          state = state.copyWith(
            currentSpeed: speed,
            result: state.result.copyWith(
              downloadSpeed: maxSpeed,
              ping: avgLatency,
              latency: avgLatency,
              jitter: jitter,
            ),
          );

          print(
              '   📥 Download ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps (Max: ${maxSpeed.toStringAsFixed(2)} Mbps, Avg: ${avgSpeed.toStringAsFixed(2)} Mbps)');
        }
      } catch (e) {
        consecutiveFailures++;
        print('   ❌ Download measurement ${i + 1} failed: $e');

        // If we have too many consecutive failures, throw to stop the test
        if (consecutiveFailures >= maxConsecutiveFailures) {
          throw Exception('Network connection lost during download test.');
        }
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = _formatBytes(bytes);

    state = state.copyWith(
      step: SpeedTestStep.upload,
      currentPhase: 'Upload test: $sizeLabel',
      progress: progress,
    );

    int consecutiveFailures = 0;
    const maxConsecutiveFailures = 3;

    for (int i = 0; i < count; i++) {
      try {
        final speed = await _measureUploadSpeed(bytes);
        if (speed > 0) {
          _uploadSpeeds.add(speed);
          consecutiveFailures = 0; // Reset on success

          // Calculate current metrics
          final maxSpeed = _uploadSpeeds.reduce((a, b) => a > b ? a : b);
          final avgSpeed = _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;

          // Calculate jitter from latency measurements
          int jitter = 0;
          if (_latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < _latencies.length; j++) {
              jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (_latencies.length - 1)).round();
          }

          // Calculate packet loss
          double packetLoss = 0.0;
          if (_latencies.length > 10) {
            final expectedPackets = _measurements
                .where((m) => m['type'] == 'latency')
                .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
            packetLoss =
                ((expectedPackets - _latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
          }

          // Update state with current speed and all metrics immediately
          state = state.copyWith(
            currentSpeed: speed,
            result: state.result.copyWith(
              uploadSpeed: maxSpeed,
              jitter: jitter,
              packetLoss: packetLoss,
            ),
          );

          print(
              '   📤 Upload ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps (Max: ${maxSpeed.toStringAsFixed(2)} Mbps, Avg: ${avgSpeed.toStringAsFixed(2)} Mbps)');
        }
      } catch (e) {
        consecutiveFailures++;
        print('   ❌ Upload measurement ${i + 1} failed: $e');

        // If we have too many consecutive failures, throw to stop the test
        if (consecutiveFailures >= maxConsecutiveFailures) {
          throw Exception('Network connection lost during upload test.');
        }
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<double> _measureDownloadSpeed(int bytes) async {
    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;

      final response = await _api.downloadTest(
        bytes: bytes,
        measurementId: _measurementId,
        during: 'download',
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;

          // Update UI every 100ms to show real-time progress
          if (elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (received * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;

            // Update current speed in state for real-time UI updates
            state = state.copyWith(currentSpeed: currentSpeedMbps);
            lastUpdateTime = now;
          }
        },
      );

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;

      if (durationSeconds < 0.01) return 0.0; // Too fast to be accurate

      final actualBytes = response.data.length;
      final bits = actualBytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      return mbps;
    } catch (e) {
      print('   ❌ Download measurement error: $e');
      throw Exception('Download failed: $e');
    }
  }

  Future<double> _measureUploadSpeed(int bytes) async {
    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;
      final completer = Completer<double>();

      final streamController = StreamController<List<int>>();
      const chunkSize = 65536; // 64KB chunks
      int sentBytes = 0;

      Future.microtask(() async {
        final random = Random();
        while (sentBytes < bytes) {
          if (streamController.isClosed) break;
          final remaining = bytes - sentBytes;
          final size = min(chunkSize, remaining);
          final chunk = List<int>.generate(size, (_) => random.nextInt(256));
          streamController.add(chunk);
          sentBytes += size;
          await Future.delayed(const Duration(microseconds: 1)); // Allow event loop to process
        }
        await streamController.close();
      });

      _api.uploadTest(
        streamController.stream,
        contentLength: bytes,
        measurementId: _measurementId,
        during: 'upload',
        onSendProgress: (sent, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;

          // Update UI every 100ms to show real-time progress
          if (elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (sent * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;

            // Update current speed in state for real-time UI updates
            state = state.copyWith(currentSpeed: currentSpeedMbps);
            lastUpdateTime = now;
          }
        },
      ).then((_) {
        final duration = DateTime.now().difference(startTime);
        final durationSeconds = duration.inMilliseconds / 1000.0;

        if (durationSeconds < 0.01) {
          completer.complete(0.0);
          return;
        }

        final bits = bytes * 8;
        final bps = bits / durationSeconds;
        final mbps = bps / 1000000;
        completer.complete(mbps);
      }).catchError((e) {
        print('   ❌ Upload measurement error: $e');
        if (!streamController.isClosed) {
          streamController.close();
        }
        completer.completeError(Exception('Upload failed: $e'));
      });

      return completer.future;
    } catch (e) {
      print('   ❌ Upload measurement error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  void _calculateFinalResults() {
    // Calculate percentile-based speeds (following Cloudflare's methodology)
    final finalDownloadSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
    final finalUploadSpeed = _calculatePercentile(_uploadSpeeds, 0.9);
    final finalLatency =
        _calculatePercentile(_latencies.map((e) => e.toDouble()).toList(), 0.5).round();

    // Calculate jitter and packet loss
    int jitter = 0;
    if (_latencies.length >= 2) {
      List<int> jitterValues = [];
      for (int i = 1; i < _latencies.length; i++) {
        jitterValues.add((_latencies[i] - _latencies[i - 1]).abs());
      }
      jitter = jitterValues.isNotEmpty
          ? (jitterValues.reduce((a, b) => a + b) / jitterValues.length).round()
          : 0;
    }

    // Packet loss estimation (simplified - would need WebRTC for real packet loss)
    double packetLoss = 0.0;
    if (_latencies.length > 10) {
      final expectedPackets = _measurements
          .where((m) => m['type'] == 'latency')
          .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
      packetLoss =
          ((expectedPackets - _latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
    }

    state = state.copyWith(
      result: SpeedTestResult(
        downloadSpeed: finalDownloadSpeed,
        uploadSpeed: finalUploadSpeed,
        ping: finalLatency,
        latency: finalLatency,
        jitter: jitter,
        packetLoss: packetLoss,
      ),
      progress: 1.0,
      currentPhase: 'Test completed',
    );

    // Log results to Cloudflare (optional)
    _logResultsToCloudflare();
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Future<void> _logResultsToCloudflare() async {
    try {
      final logData = {
        'measId': _measurementId,
        'downloadMbps': state.result.downloadSpeed,
        'uploadMbps': state.result.uploadSpeed,
        'latencyMs': state.result.latency,
        'jitterMs': state.result.jitter,
        'packetLossPercent': state.result.packetLoss,
        'timestamp': DateTime.now().toIso8601String(),
        'client': 'DefyxVPN-Flutter',
      };

      await _api.logMeasurement(logData: logData);
      print('📊 Results logged to Cloudflare');
    } catch (e) {
      print('⚠️ Failed to log results to Cloudflare: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(0)}KB';
    if (bytes < 1000000000) return '${(bytes / 1000000).toStringAsFixed(0)}MB';
    return '${(bytes / 1000000000).toStringAsFixed(0)}GB';
  }

  void _checkConnectionStability() {
    final isStable = state.result.packetLoss < 5.0 &&
        state.result.jitter < 50 &&
        state.result.downloadSpeed > 0.1 &&
        state.result.uploadSpeed > 0.1;

    if (!isStable) {
      state = state.copyWith(
        step: SpeedTestStep.toast,
        isConnectionStable: false,
      );
    } else {
      state = state.copyWith(step: SpeedTestStep.ads);
    }
  }

  void resetTest() {
    state = const SpeedTestState();
  }

  void retryConnection() {
    // Reset to ready state first
    state = const SpeedTestState();
    // Then start the test
    startTest();
  }

  void moveToAds() {
    state = state.copyWith(step: SpeedTestStep.ads);
  }

  void completeTest() {
    state = state.copyWith(step: SpeedTestStep.ready);
  }
}
