import 'package:flutter/foundation.dart';
import '../../data/api/speed_test_api.dart';
import '../../models/speed_test_result.dart';
import '../../../../shared/services/telemetry_consent_service.dart';

class CloudflareLoggerService {
  final SpeedTestApi api;

  CloudflareLoggerService(this.api);
  final _telemetry = TelemetryConsentService();

  Future<void> logResults({
    required String measurementId,
    required SpeedTestResult result,
  }) async {
    if (!_telemetry.isCollectionEnabled) {
      debugPrint('Telemetry disabled; speed-test results stay local');
      return;
    }

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
