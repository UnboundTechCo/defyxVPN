import 'package:defyx_vpn/core/utils/update_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('minimumForcedVersion', () {
    test('nothing forced gives no minimum', () {
      final forceUpdate = {
        '5.12.5': false,
        '5.13.2': false,
        '5.13.3': false,
        '5.13.3+316': false,
      };
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), isNull);
    });

    test('an earlier forced version stays the minimum after unforced ones', () {
      final forceUpdate = {'5.12.5': true, '5.13.2': false};
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), '5.12.5');
    });

    test('picks the highest forced version the store offers', () {
      final forceUpdate = {'5.10.0': true, '5.12.5': true, '5.13.2': false};
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), '5.12.5');
    });

    test('the latest version itself counts when forced', () {
      final forceUpdate = {'5.12.5': true, '5.13.2': true};
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), '5.13.2');
    });

    test('skips forced versions this store does not offer yet', () {
      // googlePlay is on 5.13.2 while appleStore already has a forced 5.13.3.
      final forceUpdate = {'5.12.5': true, '5.13.3': true};
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), '5.12.5');
    });

    test('build numbers are ignored when comparing', () {
      final forceUpdate = {'5.13.3+316': true};
      expect(minimumForcedVersion(forceUpdate, '5.13.3+320'), '5.13.3+316');
      expect(minimumForcedVersion(forceUpdate, '5.13.2'), isNull);
    });

    test('missing or malformed data gives no minimum', () {
      expect(minimumForcedVersion(null, '5.13.2'), isNull);
      expect(minimumForcedVersion({'5.12.5': true}, null), isNull);
      expect(minimumForcedVersion({'not-a-version': true}, '5.13.2'), isNull);
    });
  });

  group('parseAppVersion', () {
    test('drops the build number', () {
      expect(parseAppVersion('5.13.3+316').toString(), '5.13.3');
    });

    test('returns null for bad input', () {
      expect(parseAppVersion(null), isNull);
      expect(parseAppVersion(''), isNull);
      expect(parseAppVersion('abc'), isNull);
      expect(parseAppVersion(5), isNull);
    });
  });
}
