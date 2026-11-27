import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:defyx_vpn/shared/services/app_traffic.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('in-app web view', () {
    const hosts = {'defyxvpn.com'};
    bool allows(String url) => webViewAllows(Uri.parse(url), hosts);

    test('shows https pages of the site and its subdomains', () {
      expect(allows('https://defyxvpn.com/privacy-policy'), isTrue);
      expect(allows('https://www.defyxvpn.com/terms'), isTrue);
      expect(allows('https://DefyxVPN.com/'), isTrue);
    });

    test('refuses plain http, other sites and look-alikes', () {
      expect(allows('http://defyxvpn.com/privacy-policy'), isFalse);
      expect(allows('https://example.com/'), isFalse);
      expect(allows('https://notdefyxvpn.com/'), isFalse);
      expect(allows('https://defyxvpn.com.example.com/'), isFalse);
    });

    test('allows the company sites the pages redirect to', () {
      final hosts = webViewDefaultHosts('https://donate.defyxvpn.com/');
      bool opens(String url) => webViewAllows(Uri.parse(url), hosts);
      expect(opens('https://donate.defyxvpn.com/give'), isTrue);
      expect(opens('https://unboundtech.de/defyx/privacy-policy'), isTrue);
      expect(opens('https://example.com/'), isFalse);
    });

    test('refuses other schemes', () {
      expect(allows('intent://scan/#Intent;scheme=zxing;end'), isFalse);
      expect(allows('file:///data/data/de.unboundtech.defyxvpn/'), isFalse);
      expect(allows('javascript:alert(1)'), isFalse);
    });
  });

  group('core analytics events', () {
    test('keep only the listed fields of a listed event', () {
      final sent = FirebaseAnalyticsService.filterCoreEvent('connect', {
        'method': 'xray',
        'step': 'a1',
        'asn': 'Example ISP',
        'device': 'android',
        'server_ip': '203.0.113.7',
      });
      expect(sent, {
        'method': 'xray',
        'step': 'a1',
        'asn': 'Example ISP',
        'device': 'android',
      });
    });

    test('drop events that are not listed', () {
      expect(
        FirebaseAnalyticsService.filterCoreEvent('anything', {'a': 'b'}),
        isNull,
      );
    });
  });

  group('app traffic', () {
    tearDown(() {
      AppTraffic.setConnected(false);
      AppTraffic.debugApplies = null;
    });

    test('goes through the core proxy only while connected', () {
      AppTraffic.debugApplies = true;
      final api = Uri.parse('https://api.example.com/plans');

      expect(AppTraffic.proxyFor(api), 'DIRECT');
      AppTraffic.setConnected(true);
      expect(AppTraffic.proxyFor(api), 'PROXY 127.0.0.1:5000');
      expect(
        AppTraffic.proxyFor(Uri.parse('http://127.0.0.1:5000/')),
        'DIRECT',
      );
      AppTraffic.setConnected(false);
      expect(AppTraffic.proxyFor(api), 'DIRECT');
    });

    test('stays direct where the tunnel already carries the app', () {
      AppTraffic.debugApplies = false;
      AppTraffic.setConnected(true);
      expect(
        AppTraffic.proxyFor(Uri.parse('https://api.example.com/')),
        'DIRECT',
      );
    });
  });
}
