enum MeasurementType { latency, download, upload }

/// One step of the speed test: [count] latency probes, or [count] transfers
/// of [bytes] each.
class MeasurementStep {
  final MeasurementType type;
  final int bytes;
  final int count;

  /// Latency probes whose samples are thrown away. The first request of a run
  /// also pays for DNS, TCP, TLS and the proxy CONNECT, so it is not a ping.
  final bool warmUp;

  const MeasurementStep.latency(this.count, {this.warmUp = false})
      : type = MeasurementType.latency,
        bytes = 0;

  const MeasurementStep.download(this.bytes, this.count)
      : type = MeasurementType.download,
        warmUp = false;

  const MeasurementStep.upload(this.bytes, this.count)
      : type = MeasurementType.upload,
        warmUp = false;
}

/// Tuning for the speed test. Timing and result rules follow Cloudflare's own
/// engine (https://github.com/cloudflare/speedtest).
class SpeedMeasurementConfig {
  /// Grouped by direction so the screen moves through latency, download and
  /// upload once each. Bandwidth steps grow in size; a direction stops early
  /// once its requests get slow (see [finishRequestDuration]).
  static const List<MeasurementStep> measurements = [
    MeasurementStep.latency(1, warmUp: true),
    MeasurementStep.latency(20),
    MeasurementStep.download(100000, 10),
    MeasurementStep.download(1000000, 8),
    MeasurementStep.download(10000000, 6),
    MeasurementStep.upload(100000, 8),
    MeasurementStep.upload(1000000, 6),
    MeasurementStep.upload(10000000, 4),
  ];

  static const String baseUrl = 'https://speed.cloudflare.com';
  static const String userAgent = 'Defyx VPN Speed Test';

  /// Local mixed (HTTP + SOCKS) inbound of the VPN core. Platforms whose
  /// tunnel does not carry the app's own traffic reach the VPN through it.
  static const String vpnProxyHost = '127.0.0.1';
  static const int vpnProxyPort = 5000;
  static const Duration vpnProxyProbeTimeout = Duration(milliseconds: 800);

  static const Duration connectTimeout = Duration(seconds: 15);

  /// Longest silence allowed between two chunks of a response.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Longest time allowed to send a whole upload body.
  static const Duration sendTimeout = Duration(seconds: 60);

  /// How long to wait before the single retry of a rate-limited (429) request.
  static const Duration rateLimitRetryDelay = Duration(seconds: 1);
  static const Duration maxRateLimitRetryDelay = Duration(seconds: 3);

  static const int maxConsecutiveFailures = 3;
  static const int uploadChunkSize = 64 * 1024;
  static const Duration latencyGap = Duration(milliseconds: 10);
  static const Duration transferGap = Duration(milliseconds: 20);

  /// Bytes on the wire per payload byte (HTTP headers and framing).
  static const double transferOverhead = 1.005;

  static const double bandwidthPercentile = 0.9;
  static const double latencyPercentile = 0.5;

  /// Transfers shorter than this are too short to measure bandwidth and are
  /// left out of the result.
  static const Duration minRequestDuration = Duration(milliseconds: 10);

  /// Once [finishMinSamples] transfers of a step all took longer than this,
  /// the link is saturated and larger steps in that direction are skipped.
  static const Duration finishRequestDuration = Duration(seconds: 1);
  static const int finishMinSamples = 3;

  /// No new transfer starts after a direction has run this long.
  static const Duration phaseTimeBudget = Duration(seconds: 15);

  /// The first bytes of an upload only fill the socket buffer. Progress
  /// events from this early part of a request don't feed the live value.
  static const Duration uploadBufferFillTime = Duration(milliseconds: 100);

  /// Live speed: bytes are counted over windows of at least this length and
  /// smoothed with an exponential moving average.
  static const Duration liveSpeedWindow = Duration(milliseconds: 250);
  static const double liveSpeedSmoothing = 0.3;
  static const Duration liveSpeedUiInterval = Duration(milliseconds: 150);

  /// How long the final value of a direction stays on screen before the
  /// next direction starts.
  static const Duration phaseResultHold = Duration(milliseconds: 900);

  /// A finished test is reported as slow or unstable when any of these holds.
  static const double unstableMinSpeedMbps = 0.1;
  static const double unstableFailureRate = 0.2;
  static const int unstableJitterMs = 150;

  static String formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(0)}KB';
    if (bytes < 1000000000) return '${(bytes / 1000000).toStringAsFixed(0)}MB';
    return '${(bytes / 1000000000).toStringAsFixed(0)}GB';
  }
}
