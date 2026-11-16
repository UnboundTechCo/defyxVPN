class SubscriptionUsageResponse {
  final double usedVolumeGb;
  final double remainingVolumeGb;
  final double totalVolumeGb;
  final int remainingDays;
  final int totalDays;
  final DateTime expireAt;

  const SubscriptionUsageResponse({
    required this.usedVolumeGb,
    required this.remainingVolumeGb,
    required this.totalVolumeGb,
    required this.remainingDays,
    required this.totalDays,
    required this.expireAt,
  });

  factory SubscriptionUsageResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsageResponse(
      usedVolumeGb: (json['used_volume_gb'] as num).toDouble(),
      remainingVolumeGb: (json['remaining_volume_gb'] as num).toDouble(),
      totalVolumeGb: (json['total_volume_gb'] as num).toDouble(),
      remainingDays: (json['remaining_days'] as num).toInt(),
      totalDays: (json['total_days'] as num).toInt(),
      expireAt: DateTime.parse(json['expire_at'] as String),
    );
  }

  double get usedVolumeFraction =>
      _fraction(totalVolumeGb - remainingVolumeGb, totalVolumeGb);

  double get usedDaysFraction =>
      _fraction((totalDays - remainingDays).toDouble(), totalDays.toDouble());

  static double _fraction(double used, double total) {
    if (total <= 0) return 0;
    return (used / total).clamp(0.0, 1.0);
  }
}
