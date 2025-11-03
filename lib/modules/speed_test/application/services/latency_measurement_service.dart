import 'package:flutter/foundation.dart';
import '../../data/api/speed_test_api.dart';
import 'speed_measurement_config.dart';

class LatencyMeasurementService {
  final SpeedTestApi api;
  final String measurementId;
  final Function(bool) isCanceledCheck;
  final Function(int ping, int latency, int jitter) onMetricsUpdate;

  final List<int> latencies = [];

  LatencyMeasurementService({
    required this.api,
    required this.measurementId,
    required this.isCanceledCheck,
    required this.onMetricsUpdate,
  });

  Future<void> runMeasurement(Map<String, dynamic> config) async {
    final numPackets = config['numPackets'] as int;
    int consecutiveFailures = 0;

    for (int i = 0; i < numPackets; i++) {
      if (isCanceledCheck(false)) {
        debugPrint('🛑 Latency measurement canceled');
        return;
      }

      try {
        final startTime = DateTime.now();
        await api.latencyTest(
          bytes: 0,
          measurementId: measurementId,
        );
        final latency = DateTime.now().difference(startTime).inMilliseconds;

        if (isCanceledCheck(false)) {
          debugPrint('   🛑 Latency measurement canceled after completion');
          return;
        }

        latencies.add(latency);
        consecutiveFailures = 0;

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

        onMetricsUpdate(latency, avgLatency, jitter);

        debugPrint(
            '   📡 Latency ${i + 1}/$numPackets: ${latency}ms (Avg: ${avgLatency}ms, Jitter: ${jitter}ms)');
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Latency measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection failed. Please check your internet connection.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.latencyDelay);
    }

    if (latencies.isEmpty) {
      throw Exception('Failed to measure latency. Please check your internet connection.');
    }
  }
}
