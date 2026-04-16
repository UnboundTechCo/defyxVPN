import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _languageKey = 'selected_language';

enum AppLanguage {
  english('en', 'English'),
  chinese('zh', '中文');

  final String code;
  final String nativeName;

  const AppLanguage(this.code, this.nativeName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  Locale get locale => Locale(code);
}

class LanguageState {
  final AppLanguage language;
  final bool isLoading;

  const LanguageState({
    required this.language,
    this.isLoading = false,
  });

  LanguageState copyWith({
    AppLanguage? language,
    bool? isLoading,
  }) {
    return LanguageState(
      language: language ?? this.language,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  final SharedPreferences _prefs;

  LanguageNotifier(this._prefs)
      : super(LanguageState(
          language: AppLanguage.fromCode(
            _prefs.getString(_languageKey) ?? _getDeviceLanguage(),
          ),
        )) {
    final savedLang = _prefs.getString(_languageKey);
    debugPrint('🌍 Saved language preference: ${savedLang ?? "none (using device language)"}');
    debugPrint('🌍 Current app language: ${state.language.code} (${state.language.nativeName})');
  }

  // Detect device language on first launch
  static String _getDeviceLanguage() {
    try {
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      debugPrint('🌍 Device locale detected: ${deviceLocale.languageCode}');
      // If device is Chinese, use Chinese; otherwise default to English
      final selectedLang = deviceLocale.languageCode == 'zh' ? 'zh' : 'en';
      debugPrint('🌍 Selected language: $selectedLang');
      return selectedLang;
    } catch (e) {
      debugPrint('🌍 Error detecting device language: $e');
      // Fallback to English if detection fails
      return 'en';
    }
  }

  Future<void> changeLanguage(AppLanguage language) async {
    debugPrint('🌍 Changing language to: ${language.code} (${language.nativeName})');
    state = state.copyWith(isLoading: true);
    await _prefs.setString(_languageKey, language.code);
    debugPrint('🌍 Language saved to SharedPreferences');
    state = state.copyWith(language: language, isLoading: false);
    debugPrint('🌍 Language state updated to: ${state.language.code}');
  }

  Locale get currentLocale => state.language.locale;
}

final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  throw UnimplementedError('languageProvider must be overridden');
});

final languageInitProvider = FutureProvider<LanguageNotifier>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LanguageNotifier(prefs);
});
