import 'package:defyx_vpn/modules/settings/models/popular_app.dart';
import 'package:defyx_vpn/modules/settings/models/split_tunnel_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? domain(String value) =>
      SplitTunnelRule.normalize(SplitTunnelRuleType.domain, value);
  String? geoip(String value) =>
      SplitTunnelRule.normalize(SplitTunnelRuleType.geoip, value);

  test('domain rules accept hostnames only', () {
    expect(domain(' Example.COM '), 'example.com');
    expect(domain('sub.example-site.co.uk'), 'sub.example-site.co.uk');
    expect(domain('t.me'), 't.me');
    expect(domain('example.xn--p1ai'), 'example.xn--p1ai');

    for (final invalid in [
      '',
      'test',
      'ir',
      'example.c',
      'example.123',
      '   ',
      'تیتیتیت',
      'exa mple.com',
      'example..com',
      '.example.com',
      'example.com.',
      '-example.com',
      'example-.com',
      'https://example.com',
      'example.com/path',
      '8.8.8.8',
      '10.0.0.0/8',
      '2001:db8::1',
    ]) {
      expect(domain(invalid), isNull, reason: invalid);
    }
  });

  test('geoip rules accept country codes, addresses and ranges', () {
    expect(geoip(' IR '), 'ir');
    expect(geoip('8.8.8.8'), '8.8.8.8');
    expect(geoip('10.0.0.0/8'), '10.0.0.0/8');
    expect(geoip('0.0.0.0/0'), '0.0.0.0/0');
    expect(geoip('2001:DB8::1'), '2001:db8::1');
    expect(geoip('2001:b28:f23c::/47'), '2001:b28:f23c::/47');

    for (final invalid in [
      '',
      'تیتیتیت',
      'iran',
      'i',
      '12',
      'example.com',
      '256.1.1.1',
      '1.2.3',
      '1.2.3.4.5',
      '10.0.0.0/33',
      '10.0.0.0/',
      '10.0.0.0/8/8',
      '10.0.0.0/-1',
      '2001:db8::/129',
      'fe80::1%eth0',
      '8.8.8.8 ir',
    ]) {
      expect(geoip(invalid), isNull, reason: invalid);
    }
  });

  test('popular app rules pass validation', () {
    for (final app in popularApps) {
      for (final value in app.domains) {
        expect(domain(value), value, reason: '${app.id} $value');
      }
      for (final value in app.addresses) {
        expect(geoip(value), value, reason: '${app.id} $value');
      }
    }
  });
}
