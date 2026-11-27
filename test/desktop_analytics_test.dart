import 'package:defyx_vpn/shared/services/desktop_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('measurement protocol payload', () {
    test('carries the event, session fields, user and device', () {
      final body = DesktopAnalytics.payload(
        clientId: '123.456',
        sessionId: 1700000000,
        name: 'vpn_connected',
        parameters: {'connection_method': 'xray', 'duration': 12},
        userId: 'user-1',
        userProperties: {'app_version': '4.2.0'},
        device: {'category': 'desktop', 'operating_system': 'Linux'},
      );

      expect(body, {
        'client_id': '123.456',
        'user_id': 'user-1',
        'user_properties': {
          'app_version': {'value': '4.2.0'},
        },
        'device': {'category': 'desktop', 'operating_system': 'Linux'},
        'events': [
          {
            'name': 'vpn_connected',
            'params': {
              'connection_method': 'xray',
              'duration': 12,
              'session_id': 1700000000,
              'engagement_time_msec': 100,
            },
          },
        ],
      });
    });

    test('leaves out an unset user and empty user properties', () {
      final body = DesktopAnalytics.payload(
        clientId: 'c',
        sessionId: 1,
        name: 'vpn_disconnected',
      );
      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('user_properties'), isFalse);
      expect(body.containsKey('device'), isFalse);
    });

    test('keeps within the protocol limits', () {
      final body = DesktopAnalytics.payload(
        clientId: 'c',
        sessionId: 1,
        name: 'n' * 50,
        parameters: {
          for (var i = 0; i < 30; i++) 'p$i': 'v' * 150,
        },
        userProperties: {'asn': 'a' * 50},
      );
      final event = (body['events'] as List).single as Map;
      final params = event['params'] as Map;

      expect((event['name'] as String).length, 40);
      expect(params.length, 25);
      expect(params['session_id'], 1);
      expect(params['engagement_time_msec'], 100);
      expect(
        params.values.whereType<String>().every((v) => v.length <= 100),
        isTrue,
      );
      final props = body['user_properties'] as Map;
      expect(((props['asn'] as Map)['value'] as String).length, 36);
    });
  });

  group('error description', () {
    test('removes IP addresses', () {
      final text = DesktopAnalytics.describeError(
        'SocketException: Connection refused, address = 203.0.113.7, '
        'port = 443, via 2001:db8::1',
      );
      expect(text, isNot(contains('203.0.113.7')));
      expect(text, isNot(contains('2001:db8::1')));
      expect(text, contains('<ip>'));
    });

    test('removes the home folder', () {
      final text = DesktopAnalytics.describeError(
        r"FileSystemException: Cannot open file, path = 'C:\Users\alice\AppData\x.json'",
        home: r'C:\Users\alice',
      );
      expect(text, isNot(contains('alice')));
      expect(text, contains(r'~\AppData\x.json'));
    });

    test('fits one event field', () {
      expect(DesktopAnalytics.describeError('x' * 500).length, 100);
    });
  });

  group('os version', () {
    test('reads the Windows build', () {
      expect(
        DesktopAnalytics.osVersion('"Windows 10 Pro" 10.0 (Build 19045)'),
        '10.0.19045',
      );
    });

    test('reads the Linux kernel release', () {
      expect(
        DesktopAnalytics.osVersion(
          'Linux 6.8.0-45-generic #45-Ubuntu SMP PREEMPT_DYNAMIC Fri Aug 30',
        ),
        '6.8.0-45-generic',
      );
    });
  });
}
