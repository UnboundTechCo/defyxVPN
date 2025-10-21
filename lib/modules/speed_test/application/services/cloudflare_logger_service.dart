import 'package:flutter/foundation.dart';
import '../../data/api/speed_test_api.dart';
import '../../models/speed_test_result.dart';

class CloudflareLoggerService {
  final SpeedTestApi api;

  CloudflareLoggerService(this.api);

  Future<void> logResults({
    required String measurementId,
    required SpeedTestResult result,
  }) async {
    try {
      final logData = {
        'measId': measurementId,
        'downloadMbps': result.downloadSpeed,
        'uploadMbps': result.uploadSpeed,
        'latencyMs': result.latency,
        'jitterMs': result.jitter,
        'packetLossPercent': result.packetLoss,
        'timestamp': DateTime.now().toIso8601String(),
        'client': 'DefyxVPN-Flutter',
      };

      await api.logMeasurement(logData: logData);
      debugPrint('📊 Results logged to Cloudflare');
    } catch (e) {
      debugPrint('⚠️ Failed to log results to Cloudflare: $e');
    }
  }
}
