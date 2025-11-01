enum SpeedTestStep {
  ready,
  loading,
  download,
  upload,
}

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final int ping;
  final int latency;
  final double packetLoss;
  final int jitter;

  const SpeedTestResult({
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.ping = 0,
    this.latency = 0,
    this.packetLoss = 0.0,
    this.jitter = 0,
  });

  SpeedTestResult copyWith({
    double? downloadSpeed,
    double? uploadSpeed,
    int? ping,
    int? latency,
    double? packetLoss,
    int? jitter,
  }) {
    return SpeedTestResult(
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      latency: latency ?? this.latency,
      packetLoss: packetLoss ?? this.packetLoss,
      jitter: jitter ?? this.jitter,
    );
  }
}
