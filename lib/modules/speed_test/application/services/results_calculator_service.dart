import '../../models/speed_test_result.dart';

class ResultsCalculatorService {
  static SpeedTestResult calculateFinalResults({
    required List<double> downloadSpeeds,
    required List<double> uploadSpeeds,
    required List<int> latencies,
    required List<Map<String, dynamic>> measurements,
  }) {
    final finalDownloadSpeed = _calculatePercentile(downloadSpeeds, 0.9);
    final finalUploadSpeed = _calculatePercentile(uploadSpeeds, 0.9);

    final ping = latencies.isNotEmpty ? latencies.reduce((a, b) => a < b ? a : b) : 0;

    final latency = _calculatePercentile(latencies.map((e) => e.toDouble()).toList(), 0.5).round();

    int jitter = 0;
    if (latencies.length >= 2) {
      List<int> jitterValues = [];
      for (int i = 1; i < latencies.length; i++) {
        jitterValues.add((latencies[i] - latencies[i - 1]).abs());
      }
      jitter = jitterValues.isNotEmpty
          ? (jitterValues.reduce((a, b) => a + b) / jitterValues.length).round()
          : 0;
    }

    double packetLoss = 0.0;
    if (latencies.length > 10) {
      final expectedPackets = measurements
          .where((m) => m['type'] == 'latency')
          .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
      packetLoss = ((expectedPackets - latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
    }

    return SpeedTestResult(
      downloadSpeed: finalDownloadSpeed,
      uploadSpeed: finalUploadSpeed,
      ping: ping,
      latency: latency,
      jitter: jitter,
      packetLoss: packetLoss,
    );
  }

  static double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  static bool checkConnectionStability(SpeedTestResult result) {
    return result.packetLoss < 5.0 &&
        result.jitter < 50 &&
        result.downloadSpeed > 0.1 &&
        result.uploadSpeed > 0.1;
  }
}
