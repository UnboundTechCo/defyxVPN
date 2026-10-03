import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _hapticsEnabledKey = 'haptics_enabled';

class HapticsNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  HapticsNotifier(this._prefs)
      : super(_prefs.getBool(_hapticsEnabledKey) ?? true);

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_hapticsEnabledKey, enabled);
    state = enabled;
  }
}

final hapticsProvider = StateNotifierProvider<HapticsNotifier, bool>((ref) {
  throw UnimplementedError('hapticsProvider must be overridden');
});
