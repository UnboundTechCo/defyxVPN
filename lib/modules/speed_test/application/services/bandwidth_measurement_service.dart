import 'package:flutter/foundation.dart';

import '../../data/speed_test_client.dart';
import 'live_speed_meter.dart';
import 'speed_measurement_config.dart';
import 'speed_test_samples.dart';

/// Runs the download or upload steps of one run and keeps the live speed.
///
/// Create one per direction: it tracks how long the direction has been
/// running and whether the link is already saturated, and stops starting new
/// transfers once either says the direction is done.
class BandwidthMeasurementService {
  BandwidthMeasurementService({
    required this.type,
    required this.client,
    required this.measurementId,
    required this.samples,
    required this.isCancelled,
    required this.onLiveSpeed,
    required this.onSample,
  }) : assert(type != MeasurementType.latency);

  final MeasurementType type;
  final SpeedTestClient client;
  final String measurementId;
  final SpeedTestSamples samples;
  final bool Function() isCancelled;

  /// Called with the smoothed live speed whenever it changes.
  final void Function(double mbps) onLiveSpeed;

  /// Called after every completed transfer.
  final VoidCallback onSample;

  final LiveSpeedMeter _meter = LiveSpeedMeter();
  final Stopwatch _clock = Stopwatch()..start();
  bool _finished = false;

  bool get _isDownload => type == MeasurementType.download;
  String get _label => _isDownload ? 'Download' : 'Upload';
  List<TransferSample> get _results =>
      _isDownload ? samples.downloads : samples.uploads;

  Future<void> run(MeasurementStep step) async {
    assert(step.type == type);
    if (_finished) return;

    final sizeLabel = SpeedMeasurementConfig.formatBytes(step.bytes);
    final payload =
        _isDownload ? null : SpeedTestClient.createPayload(step.bytes);
    final durations = <Duration>[];
    var consecutiveFailures = 0;

    for (var i = 0; i < step.count; i++) {
      if (isCancelled()) return;
      if (_clock.elapsed >= SpeedMeasurementConfig.phaseTimeBudget &&
          _results.isNotEmpty) {
        debugPrint('$_label: time budget used, skipping the remaining steps');
        _finished = true;
        return;
      }

      samples.requestAttempts++;
      _meter.beginRequest();

      try {
        final sample = _isDownload
            ? await client.download(
                step.bytes,
                measurementId,
                onChunk: _onBytes,
              )
            : await client.upload(
                payload!,
                measurementId,
                onSent: _onUploadProgress,
              );
        if (isCancelled()) return;

        consecutiveFailures = 0;
        _results.add(sample);
        durations.add(sample.duration);

        // Short transfers end before a full window; use their total instead.
        if (!_meter.measuredThisRequest &&
            sample.duration >= SpeedMeasurementConfig.minRequestDuration) {
          _meter.addSample(sample.mbps);
          onLiveSpeed(_meter.mbps);
        }
        onSample();

        debugPrint(
          '$_label ${i + 1}/${step.count} ($sizeLabel): '
          '${sample.mbps.toStringAsFixed(2)} Mbps '
          'in ${sample.duration.inMilliseconds} ms',
        );

        if (_isSaturated(durations)) {
          debugPrint('$_label: transfers take over '
              '${SpeedMeasurementConfig.finishRequestDuration.inMilliseconds} ms, '
              'skipping larger sizes');
          _finished = true;
          return;
        }
      } catch (e) {
        if (isCancelled()) return;
        samples.requestFailures++;
        consecutiveFailures++;
        debugPrint('$_label ${i + 1}/${step.count} ($sizeLabel) failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw SpeedTestException(
            'Network connection lost during the ${_label.toLowerCase()} test.',
          );
        }
      }

      await Future<void>.delayed(SpeedMeasurementConfig.transferGap);
    }
  }

  void _onBytes(int bytes) {
    if (isCancelled()) return;
    if (_meter.addBytes(bytes)) onLiveSpeed(_meter.mbps);
  }

  void _onUploadProgress(int bytes, Duration sinceStart) {
    // At first the socket buffer swallows data far faster than the network
    // can carry it; only count bytes once the buffer is full.
    if (sinceStart < SpeedMeasurementConfig.uploadBufferFillTime) return;
    _onBytes(bytes);
  }

  /// True when the last few transfers of a step each took over
  /// [SpeedMeasurementConfig.finishRequestDuration]: larger sizes would only
  /// take longer without measuring anything new.
  static bool _isSaturated(List<Duration> durations) {
    const needed = SpeedMeasurementConfig.finishMinSamples;
    if (durations.length < needed) return false;
    return durations
        .skip(durations.length - needed)
        .every((d) => d > SpeedMeasurementConfig.finishRequestDuration);
  }
}
