import 'speed_measurement_config.dart';

/// Turns raw byte counts into the smooth live speed shown during a phase.
///
/// Bytes are counted over windows of at least [window] and each window's
/// rate is blended into an exponential moving average, so the value follows
/// the real throughput without jumping on every chunk. Windows only run while
/// data flows: [beginRequest] drops the open window so the wait for the first
/// byte of the next request is not counted as slow throughput.
class LiveSpeedMeter {
  LiveSpeedMeter({
    Duration Function()? clock,
    this.window = SpeedMeasurementConfig.liveSpeedWindow,
    this.smoothing = SpeedMeasurementConfig.liveSpeedSmoothing,
  }) : _clock = clock ?? _stopwatchClock();

  final Duration Function() _clock;
  final Duration window;

  /// Weight of a new reading in the moving average (0..1).
  final double smoothing;

  double _mbps = 0;
  bool _hasValue = false;
  Duration? _windowStart;
  int _windowBytes = 0;
  int _readingsThisRequest = 0;

  /// The smoothed speed in Mbps.
  double get mbps => _mbps;

  /// Whether the current request produced at least one full window.
  bool get measuredThisRequest => _readingsThisRequest > 0;

  void beginRequest() {
    _windowStart = null;
    _windowBytes = 0;
    _readingsThisRequest = 0;
  }

  /// Records [bytes] that just arrived (or left). Returns true when this
  /// closed a window and [mbps] changed.
  bool addBytes(int bytes) {
    final now = _clock();
    final start = _windowStart;
    if (start == null) {
      // These bytes were in flight before we started watching; they only
      // mark where the window starts.
      _windowStart = now;
      return false;
    }

    _windowBytes += bytes;
    final elapsed = now - start;
    if (elapsed < window) return false;

    // bits per microsecond == megabits per second
    _add(_windowBytes * 8 / elapsed.inMicroseconds);
    _readingsThisRequest++;
    _windowStart = now;
    _windowBytes = 0;
    return true;
  }

  /// Adds a whole-request speed, for requests too short to fill a window.
  void addSample(double mbps) => _add(mbps);

  void _add(double mbps) {
    if (mbps.isNaN || mbps.isInfinite || mbps < 0) return;
    _mbps = _hasValue ? _mbps + smoothing * (mbps - _mbps) : mbps;
    _hasValue = true;
  }

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}
