import 'package:flutter/foundation.dart';

import '../../data/speed_test_client.dart';
import 'speed_measurement_config.dart';
import 'speed_test_samples.dart';

class LatencyMeasurementService {
  LatencyMeasurementService({
    required this.client,
    required this.measurementId,
    required this.samples,
    required this.isCancelled,
    required this.onSample,
  });

  final SpeedTestClient client;
  final String measurementId;
  final SpeedTestSamples samples;
  final bool Function() isCancelled;

  /// Called after every new ping sample.
  final VoidCallback onSample;

  Future<void> run(MeasurementStep step) async {
    if (step.warmUp) return _warmUp(step.count);

    var consecutiveFailures = 0;
    for (var i = 0; i < step.count; i++) {
      if (isCancelled()) return;
      samples.latencyAttempts++;
      samples.requestAttempts++;

      try {
        final ping = await client.measureLatency(measurementId);
        if (isCancelled()) return;

        samples.latenciesMs.add((ping.inMicroseconds / 1000).round());
        consecutiveFailures = 0;
        onSample();
        debugPrint('Latency ${i + 1}/${step.count}: ${ping.inMilliseconds} ms');
      } catch (e) {
        if (isCancelled()) return;
        samples.latencyFailures++;
        samples.requestFailures++;
        consecutiveFailures++;
        debugPrint('Latency ${i + 1}/${step.count} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw const SpeedTestException(
            'Network connection failed during the latency test.',
          );
        }
      }

      await Future<void>.delayed(SpeedMeasurementConfig.latencyGap);
    }
  }

  /// Opens the connection to the server. These requests include DNS, TCP,
  /// TLS and proxy setup, so their timing is not kept. A failed attempt is
  /// retried so one dropped request can't fail the whole test.
  Future<void> _warmUp(int count) async {
    for (var i = 0; i < count; i++) {
      for (var attempt = 1; ; attempt++) {
        if (isCancelled()) return;
        try {
          await client.measureLatency(measurementId);
          break;
        } catch (e) {
          if (isCancelled()) return;
          debugPrint('Speed test warm-up attempt $attempt failed: $e');
          if (attempt >= SpeedMeasurementConfig.maxConsecutiveFailures) {
            throw SpeedTestException('Could not reach the speed test server: $e');
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
  }
}
