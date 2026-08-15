import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _languageKey = 'selected_language';
const String _autoDetectKey = 'language_auto_detect';

enum AppLanguage {
  english('en', 'English'),
  // persian('fa', 'فارسی'),
  chinese('zh', '中文'),
  russian('ru', 'Русский');

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
  final bool isAutoDetect;
  final bool isLoading;

  const LanguageState({
    required this.language,
    this.isAutoDetect = true,
    this.isLoading = false,
  });

  LanguageState copyWith({
    AppLanguage? language,
    bool? isAutoDetect,
    bool? isLoading,
  }) {
    return LanguageState(
      language: language ?? this.language,
      isAutoDetect: isAutoDetect ?? this.isAutoDetect,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  final SharedPreferences _prefs;

  LanguageNotifier(this._prefs) : super(_buildInitialState(_prefs));

  static LanguageState _buildInitialState(SharedPreferences prefs) {
    final isAutoDetect = prefs.getBool(_autoDetectKey) ?? true;
    if (isAutoDetect) {
      return LanguageState(
        language: _detectDeviceLanguage(),
        isAutoDetect: true,
      );
    }
    return LanguageState(
      language: AppLanguage.fromCode(
        prefs.getString(_languageKey) ?? AppLanguage.english.code,
      ),
      isAutoDetect: false,
    );
  }

  // Auto-detect mode: resolve against the device locale, falling back to English
  static AppLanguage _detectDeviceLanguage() {
    try {
      final deviceCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return AppLanguage.values.firstWhere(
        (lang) => lang.code == deviceCode,
        orElse: () => AppLanguage.english,
      );
    } catch (e) {
      debugPrint('🌍 Error detecting device language: $e');
      return AppLanguage.english;
    }
  }

  Future<void> changeLanguage(AppLanguage language) async {
    state = state.copyWith(isLoading: true);
    await _prefs.setBool(_autoDetectKey, false);
    await _prefs.setString(_languageKey, language.code);
    state = LanguageState(language: language, isAutoDetect: false);
  }

  Future<void> enableAutoDetect() async {
    state = state.copyWith(isLoading: true);
    await _prefs.setBool(_autoDetectKey, true);
    state = LanguageState(
      language: _detectDeviceLanguage(),
      isAutoDetect: true,
    );
  }

  Locale get currentLocale => state.language.locale;
}

final languageProvider = StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) {
    throw UnimplementedError('languageProvider must be overridden');
  },
);

final languageInitProvider = FutureProvider<LanguageNotifier>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LanguageNotifier(prefs);
});
