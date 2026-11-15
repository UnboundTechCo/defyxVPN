import 'package:defyx_vpn/core/utils/format_number.dart';
import 'package:defyx_vpn/modules/speed_test/application/services/live_speed_meter.dart';
import 'package:defyx_vpn/modules/speed_test/application/services/results_calculator_service.dart';
import 'package:defyx_vpn/modules/speed_test/application/services/speed_test_samples.dart';
import 'package:defyx_vpn/modules/speed_test/data/speed_test_client.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_gauge_scale.dart';
import 'package:flutter_test/flutter_test.dart';

TransferSample _sample(double mbps, {int ms = 500}) {
  final duration = Duration(milliseconds: ms);
  // Inverse of TransferSample.mbps, overhead included.
  final bytes = (mbps * duration.inMicroseconds / 8 / 1.005).round();
  return TransferSample(bytes: bytes, duration: duration);
}

void main() {
  group('formatSpeed', () {
    test('rounds speeds of 1 Mbps and above to whole numbers', () {
      expect(formatSpeed(20.25), '20');
      expect(formatSpeed(20.5), '21');
      expect(formatSpeed(1), '1');
      expect(formatSpeed(1.49), '1');
      expect(formatSpeed(999.6), '1,000');
      expect(formatSpeed(1234.4), '1,234');
    });

    test('keeps one decimal below 1 Mbps', () {
      expect(formatSpeed(0.4), '0.4');
      expect(formatSpeed(0.44), '0.4');
      expect(formatSpeed(0.3000000000000004), '0.3');
    });

    test('values that round up to 1 show as 1, not 1.0', () {
      expect(formatSpeed(0.96), '1');
    });

    test('zero, tiny and invalid values show 0', () {
      expect(formatSpeed(0), '0');
      expect(formatSpeed(0.04), '0');
      expect(formatSpeed(-3), '0');
      expect(formatSpeed(double.nan), '0');
      expect(formatSpeed(double.infinity), '0');
    });
  });

  group('SpeedGaugeScale', () {
    test('puts each mark at an equal share of the arc', () {
      final marks = SpeedGaugeScale.marks;
      for (var i = 0; i < marks.length; i++) {
        expect(
          SpeedGaugeScale.fractionFor(marks[i]),
          closeTo(i / (marks.length - 1), 1e-9),
        );
      }
    });

    test('a drop from 20 to 0.4 Mbps moves the gauge visibly', () {
      final at20 = SpeedGaugeScale.fractionFor(20);
      final at04 = SpeedGaugeScale.fractionFor(0.4);
      expect(at04, closeTo(0.044, 0.001));
      expect(at20, closeTo(0.407, 0.001));
      expect(at20 - at04, greaterThan(0.35));
    });

    test('is monotonic and clamped to 0..1', () {
      var previous = -1.0;
      for (var mbps = 0.0; mbps <= 1200; mbps += 0.7) {
        final fraction = SpeedGaugeScale.fractionFor(mbps);
        expect(fraction, greaterThanOrEqualTo(previous));
        expect(fraction, inInclusiveRange(0, 1));
        previous = fraction;
      }
      expect(SpeedGaugeScale.fractionFor(-1), 0);
      expect(SpeedGaugeScale.fractionFor(double.nan), 0);
      expect(SpeedGaugeScale.fractionFor(5000), 1);
    });
  });

  group('LiveSpeedMeter', () {
    late Duration now;
    late LiveSpeedMeter meter;

    setUp(() {
      now = Duration.zero;
      meter = LiveSpeedMeter(
        clock: () => now,
        window: const Duration(milliseconds: 250),
        smoothing: 0.3,
      );
    });

    /// Feeds a steady [mbps] stream for [duration] in 50 ms chunks.
    void stream(double mbps, Duration duration) {
      const step = Duration(milliseconds: 50);
      final bytesPerStep = (mbps * step.inMicroseconds / 8).round();
      final end = now + duration;
      while (now < end) {
        now += step;
        meter.addBytes(bytesPerStep);
      }
    }

    test('measures a steady stream', () {
      meter.beginRequest();
      stream(40, const Duration(seconds: 2));
      expect(meter.mbps, closeTo(40, 0.5));
      expect(meter.measuredThisRequest, isTrue);
    });

    test('the wait between requests does not drag the value down', () {
      meter.beginRequest();
      stream(40, const Duration(seconds: 1));
      final before = meter.mbps;

      // Next request: nothing arrives for 400 ms (time to first byte).
      meter.beginRequest();
      now += const Duration(milliseconds: 400);
      stream(40, const Duration(seconds: 1));

      expect(meter.mbps, closeTo(before, 0.5));
    });

    test('moves gradually instead of jumping', () {
      meter.beginRequest();
      stream(40, const Duration(seconds: 2));
      stream(10, const Duration(milliseconds: 300));
      // One window at 10 Mbps only pulls the value part of the way down.
      expect(meter.mbps, inExclusiveRange(10, 40));
      expect(meter.mbps, greaterThan(25));
    });

    test('short requests fall back to their whole-request speed', () {
      meter.beginRequest();
      now += const Duration(milliseconds: 30);
      meter.addBytes(50000);
      expect(meter.measuredThisRequest, isFalse);

      meter.addSample(12);
      expect(meter.mbps, 12);
    });

    test('ignores invalid samples', () {
      meter.addSample(5);
      meter.addSample(double.nan);
      meter.addSample(double.infinity);
      meter.addSample(-1);
      expect(meter.mbps, 5);
    });
  });

  group('ResultsCalculatorService', () {
    test('percentile interpolates between values', () {
      expect(ResultsCalculatorService.percentile([], 0.9), 0);
      expect(ResultsCalculatorService.percentile([7], 0.9), 7);
      expect(ResultsCalculatorService.percentile([1, 2, 3, 4, 5], 0.5), 3);
      expect(
        ResultsCalculatorService.percentile([10, 20], 0.9),
        closeTo(19, 1e-9),
      );
    });

    test('bandwidth leaves out transfers under 10 ms', () {
      final transfers = [
        _sample(900, ms: 2), // too short to mean anything
        _sample(50),
        _sample(52),
        _sample(48),
      ];
      expect(
        ResultsCalculatorService.bandwidth(transfers),
        closeTo(51.6, 0.1),
      );
    });

    test('bandwidth uses short transfers when nothing else exists', () {
      expect(
        ResultsCalculatorService.bandwidth([_sample(30, ms: 5)]),
        closeTo(30, 0.1),
      );
    });

    test('jitter is the average change between consecutive pings', () {
      expect(ResultsCalculatorService.jitter([]), 0);
      expect(ResultsCalculatorService.jitter([100]), 0);
      expect(ResultsCalculatorService.jitter([100, 110, 100, 130]), 17);
    });

    test('calculate fills every field', () {
      final samples = SpeedTestSamples()
        ..downloads.addAll([_sample(40), _sample(50)])
        ..uploads.addAll([_sample(10), _sample(12)])
        ..latenciesMs.addAll([120, 100, 110, 140])
        ..latencyAttempts = 5
        ..latencyFailures = 1;

      final result = ResultsCalculatorService.calculate(samples);
      expect(result.downloadSpeed, closeTo(49, 0.1));
      expect(result.uploadSpeed, closeTo(11.8, 0.1));
      expect(result.ping, 100);
      expect(result.latency, 115);
      expect(result.jitter, 20);
      expect(result.packetLoss, closeTo(20, 1e-9));
    });

    group('isStable', () {
      SpeedTestSamples samples({int attempts = 50, int failures = 0}) =>
          SpeedTestSamples()
            ..requestAttempts = attempts
            ..requestFailures = failures;

      const good = SpeedTestResult(
        downloadSpeed: 25,
        uploadSpeed: 8,
        jitter: 60,
      );

      test('a normal VPN connection is stable', () {
        expect(ResultsCalculatorService.isStable(good, samples()), isTrue);
      });

      test('one or two failed requests are not instability', () {
        expect(
          ResultsCalculatorService.isStable(good, samples(failures: 2)),
          isTrue,
        );
      });

      test('flags many failed requests', () {
        expect(
          ResultsCalculatorService.isStable(good, samples(failures: 10)),
          isFalse,
        );
      });

      test('flags near-zero speed', () {
        expect(
          ResultsCalculatorService.isStable(
            const SpeedTestResult(downloadSpeed: 25, uploadSpeed: 0.05),
            samples(),
          ),
          isFalse,
        );
      });

      test('flags very high jitter', () {
        expect(
          ResultsCalculatorService.isStable(
            const SpeedTestResult(
              downloadSpeed: 25,
              uploadSpeed: 8,
              jitter: 200,
            ),
            samples(),
          ),
          isFalse,
        );
      });
    });
  });

  group('TransferSample', () {
    test('mbps counts 0.5% protocol overhead', () {
      const sample = TransferSample(
        bytes: 1000000,
        duration: Duration(seconds: 1),
      );
      expect(sample.mbps, closeTo(8.04, 1e-9));
    });

    test('zero duration gives 0', () {
      const sample = TransferSample(bytes: 1000, duration: Duration.zero);
      expect(sample.mbps, 0);
    });
  });

  group('SpeedTestClient.parseServerTime', () {
    test('reads cfRequestDuration', () {
      expect(
        SpeedTestClient.parseServerTime('cfRequestDuration;dur=12.5'),
        const Duration(microseconds: 12500),
      );
      expect(
        SpeedTestClient.parseServerTime('cfL4;desc="x", cfReqDur;dur=3'),
        const Duration(milliseconds: 3),
      );
    });

    test('falls back to the sum of cfSpeed entries', () {
      expect(
        SpeedTestClient.parseServerTime(
          'cfSpeedA;dur=1.5, cfSpeedB;dur=2.5',
        ),
        const Duration(milliseconds: 4),
      );
    });

    test('missing or unusable header gives zero', () {
      expect(SpeedTestClient.parseServerTime(null), Duration.zero);
      expect(SpeedTestClient.parseServerTime(''), Duration.zero);
      expect(SpeedTestClient.parseServerTime('foo;dur=9'), Duration.zero);
    });
  });
}
