import '../../data/speed_test_client.dart';
import '../../models/speed_test_result.dart';
import 'speed_measurement_config.dart';
import 'speed_test_samples.dart';

class ResultsCalculatorService {
  static SpeedTestResult calculate(SpeedTestSamples samples) {
    final latencies = samples.latenciesMs;

    return SpeedTestResult(
      downloadSpeed: bandwidth(samples.downloads),
      uploadSpeed: bandwidth(samples.uploads),
      ping: latencies.isEmpty ? 0 : latencies.reduce((a, b) => a < b ? a : b),
      latency: percentile(
        latencies.map((e) => e.toDouble()).toList(),
        SpeedMeasurementConfig.latencyPercentile,
      ).round(),
      jitter: jitter(latencies),
      packetLoss: samples.latencyAttempts == 0
          ? 0.0
          : samples.latencyFailures / samples.latencyAttempts * 100,
    );
  }

  /// 90th percentile of the transfer speeds. Transfers too short to measure
  /// are skipped, unless nothing else is left.
  static double bandwidth(List<TransferSample> transfers) {
    final measurable = transfers
        .where((t) => t.duration >= SpeedMeasurementConfig.minRequestDuration)
        .toList();
    final source = measurable.isNotEmpty ? measurable : transfers;
    return percentile(
      source.map((t) => t.mbps).toList(),
      SpeedMeasurementConfig.bandwidthPercentile,
    );
  }

  /// Average change between consecutive pings.
  static int jitter(List<int> latenciesMs) {
    if (latenciesMs.length < 2) return 0;
    var sum = 0;
    for (var i = 1; i < latenciesMs.length; i++) {
      sum += (latenciesMs[i] - latenciesMs[i - 1]).abs();
    }
    return (sum / (latenciesMs.length - 1)).round();
  }

  /// Linear-interpolated percentile, [p] in 0..1.
  static double percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final position = p.clamp(0.0, 1.0) * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }

  /// False when the connection is too slow, loses too many requests or its
  /// latency swings too much for the result to be meaningful.
  static bool isStable(SpeedTestResult result, SpeedTestSamples samples) {
    final failureRate = samples.requestAttempts == 0
        ? 0.0
        : samples.requestFailures / samples.requestAttempts;

    return result.downloadSpeed >= SpeedMeasurementConfig.unstableMinSpeedMbps &&
        result.uploadSpeed >= SpeedMeasurementConfig.unstableMinSpeedMbps &&
        failureRate < SpeedMeasurementConfig.unstableFailureRate &&
        result.jitter <= SpeedMeasurementConfig.unstableJitterMs;
  }
}
