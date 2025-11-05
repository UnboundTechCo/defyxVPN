import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/api/speed_test_api.dart';
import 'speed_measurement_config.dart';

class UploadMeasurementService {
  final SpeedTestApi api;
  final String measurementId;
  final Function(bool) isCanceledCheck;
  final Function(double speed) onSpeedUpdate;
  final Function(double percentileSpeed, double avgSpeed, int jitter, double packetLoss)
      onMetricsUpdate;

  final List<double> uploadSpeeds = [];
  final List<int> latencies;
  final List<Map<String, dynamic>> measurements;

  UploadMeasurementService({
    required this.api,
    required this.measurementId,
    required this.isCanceledCheck,
    required this.onSpeedUpdate,
    required this.onMetricsUpdate,
    required this.latencies,
    required this.measurements,
  });

  Future<void> runMeasurement(Map<String, dynamic> config) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);
    int consecutiveFailures = 0;

    for (int i = 0; i < count; i++) {
      if (isCanceledCheck(false)) {
        debugPrint('🛑 Upload measurement canceled');
        return;
      }

      try {
        final speed = await _measureSpeed(bytes);
        if (speed > 0 && !isCanceledCheck(false)) {
          uploadSpeeds.add(speed);
          consecutiveFailures = 0;

          final percentileSpeed = _calculatePercentile(uploadSpeeds, 0.9);
          final avgSpeed = uploadSpeeds.reduce((a, b) => a + b) / uploadSpeeds.length;

          int jitter = 0;
          if (latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < latencies.length; j++) {
              jitterSum += (latencies[j] - latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (latencies.length - 1)).round();
          }

          double packetLoss = 0.0;
          if (latencies.length > 10) {
            final expectedPackets = measurements
                .where((m) => m['type'] == 'latency')
                .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
            packetLoss =
                ((expectedPackets - latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
          }

          onMetricsUpdate(percentileSpeed, avgSpeed, jitter, packetLoss);

          debugPrint(
              '   📤 Upload ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps (90th percentile: ${percentileSpeed.toStringAsFixed(2)} Mbps, Avg: ${avgSpeed.toStringAsFixed(2)} Mbps)');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Upload measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection lost during upload test.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
    }
  }

  Future<double> _measureSpeed(int bytes) async {
    if (isCanceledCheck(false)) {
      debugPrint('   🛑 Upload measurement canceled before start');
      return 0.0;
    }

    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;
      final completer = Completer<double>();

      final streamController = StreamController<List<int>>();
      int sentBytes = 0;

      Future.microtask(() async {
        final random = Random();
        while (sentBytes < bytes) {
          if (streamController.isClosed) break;
          final remaining = bytes - sentBytes;
          final size = min(SpeedMeasurementConfig.chunkSize, remaining);
          final chunk = List<int>.generate(size, (_) => random.nextInt(256));
          streamController.add(chunk);
          sentBytes += size;
          await Future.delayed(const Duration(microseconds: 1));
        }
        await streamController.close();
      });

      api.uploadTest(
        streamController.stream,
        contentLength: bytes,
        measurementId: measurementId,
        during: 'upload',
        onSendProgress: (sent, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;

          if (!isCanceledCheck(false) &&
              elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (sent * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;
            final roundedSpeed = SpeedMeasurementConfig.roundSpeed(currentSpeedMbps);
            onSpeedUpdate(roundedSpeed);
            lastUpdateTime = now;
          }
        },
      ).then((_) {
        if (isCanceledCheck(false)) {
          debugPrint('   🛑 Upload measurement canceled after completion');
          completer.complete(0.0);
          return;
        }

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
        debugPrint('   ❌ Upload measurement error: $e');
        if (!streamController.isClosed) {
          streamController.close();
        }
        completer.completeError(Exception('Upload failed: $e'));
      });

      return completer.future;
    } catch (e) {
      debugPrint('   ❌ Upload measurement error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
