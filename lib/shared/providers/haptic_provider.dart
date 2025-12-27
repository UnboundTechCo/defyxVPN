import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final hapticEnabledProvider = StateNotifierProvider<HapticNotifier, bool>((ref) {
  return HapticNotifier();
});

class HapticNotifier extends StateNotifier<bool> {
  static const String _hapticKey = 'haptic_enabled';
  
  HapticNotifier() : super(true) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_hapticKey);
    if (savedValue != null) {
      state = savedValue;
    }
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, state);
  }
}
