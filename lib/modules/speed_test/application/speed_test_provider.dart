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

  const SpeedTestState({
    this.step = SpeedTestStep.ready,
    this.result = const SpeedTestResult(),
    this.progress = 0.0,
    this.isConnectionStable = true,
    this.errorMessage,
  });

  SpeedTestState copyWith({
    SpeedTestStep? step,
    SpeedTestResult? result,
    double? progress,
    bool? isConnectionStable,
    String? errorMessage,
  }) {
    return SpeedTestState(
      step: step ?? this.step,
      result: result ?? this.result,
      progress: progress ?? this.progress,
      isConnectionStable: isConnectionStable ?? this.isConnectionStable,
      errorMessage: errorMessage ?? this.errorMessage,
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

  SpeedTestNotifier(this._httpClient) : super(const SpeedTestState()) {
    // Get the underlying Dio instance from HttpClient
    final dio = (_httpClient as HttpClient).dio;

    // Configure Dio for speed test (larger timeouts)
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 60);
    dio.options.sendTimeout = const Duration(seconds: 60);

    // Create Retrofit API instance
    _api = SpeedTestApi(dio);
  }

  // Test configuration - different file sizes to ramp up speed
  final List<int> _downloadSizes = [
    100000, // 100 KB
    100000, // 100 KB
    1000000, // 1 MB
    1000000, // 1 MB
    10000000, // 10 MB
    10000000, // 10 MB
    25000000, // 25 MB
    25000000, // 25 MB
  ];

  final List<int> _uploadSizes = [
    100000, // 100 KB
    100000, // 100 KB
    1000000, // 1 MB
    1000000, // 1 MB
    10000000, // 10 MB
    25000000, // 25 MB
  ];

  double _maxDownloadSpeed = 0.0;
  double _maxUploadSpeed = 0.0;
  int _pingSum = 0;
  int _pingCount = 0;
  List<int> _latencies = [];

  Future<void> startTest() async {
    print('🚀 Speed test started');
    state = state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      result: const SpeedTestResult(),
    );

    // Reset max speeds
    _maxDownloadSpeed = 0.0;
    _maxUploadSpeed = 0.0;
    _pingSum = 0;
    _pingCount = 0;
    _latencies = [];

    // Initial latency test
    await _measureLatency();

    await Future.delayed(const Duration(milliseconds: 500));

    await _runDownloadTest();

    await _runUploadTest();

    _checkConnectionStability();
    print('🏁 Speed test finished');
  }

  Future<void> _measureLatency() async {
    print('📡 Measuring latency...');
    try {
      for (int i = 0; i < 5; i++) {
        final startTime = DateTime.now();
        await _api.latencyTest(bytes: 0);
        final latency = DateTime.now().difference(startTime).inMilliseconds;

        _latencies.add(latency);
        _pingSum += latency;
        _pingCount++;

        print('   Ping ${i + 1}/5: ${latency}ms');

        await Future.delayed(const Duration(milliseconds: 100));
      }

      final avgLatency = _pingCount > 0 ? (_pingSum / _pingCount).round() : 0;
      print('✅ Average latency: ${avgLatency}ms');
    } catch (e) {
      print('❌ Latency measurement error: $e');
    }
  }

  Future<void> _runDownloadTest() async {
    state = state.copyWith(step: SpeedTestStep.download, progress: 0.0);
    print('🔽 Starting download test with ${_downloadSizes.length} measurements');

    try {
      for (int i = 0; i < _downloadSizes.length; i++) {
        final bytes = _downloadSizes[i];
        print('📥 Download test ${i + 1}/${_downloadSizes.length}: ${bytes ~/ 1000} KB');

        final speed = await _measureDownloadSpeed(bytes);
        print('   Speed: ${speed.toStringAsFixed(2)} Mbps');

        if (speed > _maxDownloadSpeed) {
          _maxDownloadSpeed = speed;
          print('   ⭐ New max download speed: ${_maxDownloadSpeed.toStringAsFixed(2)} Mbps');
        }

        // Progress based on current speed vs max speed achieved so far
        // Assume max potential is 100 Mbps for progress calculation
        final progress = (_maxDownloadSpeed / 100.0).clamp(0.0, 1.0);

        final avgPing = _pingCount > 0 ? (_pingSum / _pingCount).round() : 0;
        final avgLatency = _latencies.isNotEmpty
            ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
            : 0;

        state = state.copyWith(
          progress: progress,
          result: state.result.copyWith(
            downloadSpeed: _maxDownloadSpeed,
            ping: avgPing,
            latency: avgLatency,
          ),
        );
        print('   Progress: ${(progress * 100).toStringAsFixed(0)}%');

        // Short delay between measurements
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Download test completed. Max speed: ${_maxDownloadSpeed.toStringAsFixed(2)} Mbps');
    } catch (e) {
      print('❌ Download test error: $e');
      // Don\'t stop the entire test, just log the error
      // If we have at least some speed measured, continue
      if (_maxDownloadSpeed == 0.0) {
        _maxDownloadSpeed = 1.0; // Set minimum speed to avoid division by zero
      }
    }
  }

  Future<double> _measureDownloadSpeed(int bytes) async {
    try {
      final startTime = DateTime.now();

      final response = await _api.downloadTest(
        bytes: bytes,
        onReceiveProgress: (received, total) {
          // Optional: You can add real-time progress tracking here
        },
      );

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;

      if (durationSeconds < 0.001) {
        print('   ⚠️ Duration too short: ${duration.inMilliseconds}ms');
        return 0.0;
      }

      // Use actual received bytes from response
      final actualBytes = response.data.length;

      // Calculate speed in Mbps: (bytes * 8) / (duration in seconds) / 1,000,000
      final bits = actualBytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      print('   ⏱️ Duration: ${duration.inMilliseconds}ms, Received: $actualBytes bytes');
      return mbps;
    } catch (e) {
      print('   ❌ Download measurement error: $e');
      return 0.0;
    }
  }

  Future<void> _runUploadTest() async {
    state = state.copyWith(step: SpeedTestStep.upload, progress: 0.0);
    print('🔼 Starting upload test with ${_uploadSizes.length} measurements');

    try {
      for (int i = 0; i < _uploadSizes.length; i++) {
        final bytes = _uploadSizes[i];
        print('📤 Upload test ${i + 1}/${_uploadSizes.length}: ${bytes ~/ 1000} KB');

        final speed = await _measureUploadSpeed(bytes);
        print('   Speed: ${speed.toStringAsFixed(2)} Mbps');

        if (speed > _maxUploadSpeed) {
          _maxUploadSpeed = speed;
          print('   ⭐ New max upload speed: ${_maxUploadSpeed.toStringAsFixed(2)} Mbps');
        }

        // Progress based on current speed vs max speed achieved so far
        // Assume max potential is 50 Mbps for progress calculation
        final progress = (_maxUploadSpeed / 50.0).clamp(0.0, 1.0);

        // Calculate jitter from latency measurements
        int jitter = 0;
        if (_latencies.length >= 2) {
          int jitterSum = 0;
          for (int j = 1; j < _latencies.length; j++) {
            jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
          }
          jitter = (jitterSum / (_latencies.length - 1)).round();
        }

        state = state.copyWith(
          progress: progress,
          result: state.result.copyWith(
            uploadSpeed: _maxUploadSpeed,
            jitter: jitter,
            packetLoss: 0.0, // Would need WebRTC TURN server for real packet loss
          ),
        );
        print('   Progress: ${(progress * 100).toStringAsFixed(0)}%');

        // Short delay between measurements
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Upload test completed. Max speed: ${_maxUploadSpeed.toStringAsFixed(2)} Mbps');
    } catch (e) {
      print('❌ Upload test error: $e');
      // Don\'t stop the entire test, just log the error
      if (_maxUploadSpeed == 0.0) {
        _maxUploadSpeed = 1.0; // Set minimum speed to avoid issues
      }
    }
  }

  Future<double> _measureUploadSpeed(int bytes) async {
    try {
      // Generate random data to upload
      final data = List<int>.generate(bytes, (index) => index % 256);

      final startTime = DateTime.now();

      await _api.uploadTest(
        file: data,
        onSendProgress: (sent, total) {
          // Optional: You can add real-time progress tracking here
        },
      );

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;

      if (durationSeconds < 0.001) {
        print('   ⚠️ Duration too short: ${duration.inMilliseconds}ms');
        return 0.0;
      }

      // Calculate speed in Mbps: (bytes * 8) / (duration in seconds) / 1,000,000
      final bits = bytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      print('   ⏱️ Duration: ${duration.inMilliseconds}ms, Sent: $bytes bytes');
      return mbps;
    } catch (e) {
      print('   ❌ Upload measurement error: $e');
      return 0.0;
    }
  }

  void _checkConnectionStability() {
    final isStable = state.result.packetLoss < 5.0 && state.result.jitter < 50;

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
    state = state.copyWith(isConnectionStable: true);
    startTest();
  }

  void moveToAds() {
    state = state.copyWith(step: SpeedTestStep.ads);
  }

  void completeTest() {
    state = state.copyWith(step: SpeedTestStep.ready);
  }
}
