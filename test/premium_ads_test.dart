// Premium users see no ads: premium status from the settings, and the ad
// gates that use it.

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/models/ad_load_result.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/modules/settings/constants/settings_constants.dart';
import 'package:defyx_vpn/modules/settings/models/settings_group.dart';
import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SettingsState _settings(List<SettingsItem>? connectionMethods) => SettingsState(
  groups: {
    if (connectionMethods != null)
      SettingsGroupId.connectionMethod: SettingsGroup(
        id: SettingsGroupId.connectionMethod,
        title: SettingsGroupTitle.connectionMethod,
        items: connectionMethods,
        isDraggable: true,
      ),
  },
);

SettingsItem _method(String id, {bool premium = false}) => SettingsItem(
  id: id,
  title: id,
  isEnabled: true,
  isAccessible: true,
  isPremium: premium,
);

ProviderContainer _container({required bool? premium}) {
  final container = ProviderContainer(
    overrides: [premiumStatusProvider.overrideWithValue(premium)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('premium status comes from the connection methods', () {
    expect(premiumStatusOf(_settings(null)), isNull); // Not loaded yet.
    expect(premiumStatusOf(_settings([])), isNull);
    expect(premiumStatusOf(_settings([_method('free')])), isFalse);
    expect(
      premiumStatusOf(
        _settings([_method('free'), _method('pro', premium: true)]),
      ),
      isTrue,
    );
  });

  test('ads are allowed only for users known not to be premium', () {
    expect(_container(premium: false).read(adsAllowedProvider), isTrue);
    expect(_container(premium: true).read(adsAllowedProvider), isFalse);
    expect(_container(premium: null).read(adsAllowedProvider), isFalse);
  });

  test('premium users have no active ad, so the tips show instead', () {
    expect(_container(premium: true).read(hasActiveAdProvider), isFalse);
  });

  test('no in-house ad is loaded for premium users', () async {
    final load = FutureProvider<AdLoadResult>(
      (ref) => InternalAdStrategy().loadAd(ref: ref),
    );
    final result = await _container(premium: true).read(load.future);
    expect(result.success, isFalse);
    expect(result.errorCode, 'PREMIUM');
  });
}
