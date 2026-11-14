/// Maps a speed to a position on the gauge arc.
///
/// Each step between two marks takes the same share of the arc, so slow and
/// fast connections both move the gauge visibly: 0.4 Mbps sits at about 4%
/// and 20 Mbps at about 41%, where a linear 0–100 scale would put them at
/// 0.4% and 20%.
class SpeedGaugeScale {
  static const List<double> marks = [
    0, 1, 5, 10, 25, 50, 100, 250, 500, 1000,
  ];

  /// Position on the arc for [mbps], from 0 (empty) to 1 (full).
  static double fractionFor(double mbps) {
    if (mbps.isNaN || mbps <= 0) return 0;
    final segments = marks.length - 1;
    for (var i = 1; i < marks.length; i++) {
      if (mbps <= marks[i]) {
        final withinSegment = (mbps - marks[i - 1]) / (marks[i] - marks[i - 1]);
        return (i - 1 + withinSegment) / segments;
      }
    }
    return 1;
  }
}
