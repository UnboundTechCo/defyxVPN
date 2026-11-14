import '../../data/speed_test_client.dart';

/// Everything measured during one run.
class SpeedTestSamples {
  final List<TransferSample> downloads = [];
  final List<TransferSample> uploads = [];

  /// Ping samples in milliseconds, without the warm-up probe.
  final List<int> latenciesMs = [];

  /// Latency probes sent and lost (warm-up excluded).
  int latencyAttempts = 0;
  int latencyFailures = 0;

  /// All requests of the run, for the stability check.
  int requestAttempts = 0;
  int requestFailures = 0;
}
