import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vpnEnabledKey = 'vpn_enabled';

final vpnDataProvider = FutureProvider<IVPNData>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final isEnabled = prefs.getBool(_vpnEnabledKey) ?? false;
  return VPNData._(isEnabled, prefs);
});



final class VPNData implements IVPNData {
  bool _isVPNEnabled;
  final SharedPreferences _prefs;

  VPNData._(this._isVPNEnabled, this._prefs);

  @override
  bool get isVPNEnabled => _isVPNEnabled;

  @override
  Future<void> enableVPN() async {
    _isVPNEnabled = true;
    await _prefs.setBool(_vpnEnabledKey, true);
  }

  @override
  Future<void> disableVPN() async {
    _isVPNEnabled = false;
    await _prefs.setBool(_vpnEnabledKey, false);
  }
}
