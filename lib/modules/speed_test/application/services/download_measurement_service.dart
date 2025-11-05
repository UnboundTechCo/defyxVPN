import 'package:flutter/foundation.dart';
import '../../data/api/speed_test_api.dart';
import 'speed_measurement_config.dart';

class DownloadMeasurementService {
  final SpeedTestApi api;
  final String measurementId;
  final Function(bool) isCanceledCheck;
  final Function(double speed) onSpeedUpdate;
  final Function(
          double percentileSpeed, double avgSpeed, int currentPing, int avgLatency, int jitter)
      onMetricsUpdate;

  final List<double> downloadSpeeds = [];
  final List<int> latencies;

  DownloadMeasurementService({
    required this.api,
    required this.measurementId,
    required this.isCanceledCheck,
    required this.onSpeedUpdate,
    required this.onMetricsUpdate,
    required this.latencies,
  });

  Future<void> runMeasurement(Map<String, dynamic> config) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);
    int consecutiveFailures = 0;

    for (int i = 0; i < count; i++) {
      if (isCanceledCheck(false)) {
        debugPrint('🛑 Download measurement canceled');
        return;
      }

      try {
        final speed = await _measureSpeed(bytes);
        if (speed > 0) {
          downloadSpeeds.add(speed);
          consecutiveFailures = 0;

          final percentileSpeed = _calculatePercentile(downloadSpeeds, 0.9);
          final avgSpeed = downloadSpeeds.reduce((a, b) => a + b) / downloadSpeeds.length;
          final currentPing = latencies.isNotEmpty ? latencies.last : 0;
          final avgLatency = latencies.isNotEmpty
              ? (latencies.reduce((a, b) => a + b) / latencies.length).round()
              : 0;

          int jitter = 0;
          if (latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < latencies.length; j++) {
              jitterSum += (latencies[j] - latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (latencies.length - 1)).round();
          }

          onMetricsUpdate(percentileSpeed, avgSpeed, currentPing, avgLatency, jitter);

          debugPrint(
              '   📥 Download ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps (90th percentile: ${percentileSpeed.toStringAsFixed(2)} Mbps, Avg: ${avgSpeed.toStringAsFixed(2)} Mbps)');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Download measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection lost during download test.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
    }
  }

  Future<double> _measureSpeed(int bytes) async {
    if (isCanceledCheck(false)) {
      debugPrint('   🛑 Download measurement canceled before start');
      return 0.0;
    }

    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;

      final response = await api.downloadTest(
        bytes: bytes,
        measurementId: measurementId,
        during: 'download',
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;

          if (!isCanceledCheck(false) &&
              elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (received * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;
            final roundedSpeed = SpeedMeasurementConfig.roundSpeed(currentSpeedMbps);
            onSpeedUpdate(roundedSpeed);
            lastUpdateTime = now;
          }
        },
      );

      if (isCanceledCheck(false)) {
        debugPrint('   🛑 Download measurement canceled after completion');
        return 0.0;
      }

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;

      if (durationSeconds < 0.01) return 0.0;

      final actualBytes = response.data.length;
      final bits = actualBytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      return mbps;
    } catch (e) {
      debugPrint('   ❌ Download measurement error: $e');
      throw Exception('Download failed: $e');
    }
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
