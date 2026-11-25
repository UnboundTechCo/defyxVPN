import 'package:defyx_vpn/modules/settings/constants/settings_constants.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium status, read from the settings: the server lists premium
/// connection methods only for premium accounts. Null while unknown - the
/// connection methods are not loaded yet (just after launch, or on a fresh
/// install before the first flowline).
bool? premiumStatusOf(SettingsState settings) {
  final methods = settings.groups[SettingsGroupId.connectionMethod]?.items;
  if (methods == null || methods.isEmpty) return null;
  return methods.any((item) => item.isPremium);
}

final premiumStatusProvider = Provider<bool?>(
  (ref) => premiumStatusOf(ref.watch(settingsProvider)),
);

/// Whether ads may be requested or shown: only once the user is known not to
/// be premium. Premium users see no ads at all - not AdMob, not in-house, not
/// the ad consent form - not even briefly while the settings load.
final adsAllowedProvider = Provider<bool>(
  (ref) => ref.watch(premiumStatusProvider) == false,
);
