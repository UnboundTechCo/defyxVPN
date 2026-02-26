import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _languageKey = 'selected_language';

enum AppLanguage {
  english('en', 'English'),
  persian('fa', 'فارسی'),
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
            _prefs.getString(_languageKey) ?? 'en',
          ),
        ));

  Future<void> changeLanguage(AppLanguage language) async {
    state = state.copyWith(isLoading: true);
    await _prefs.setString(_languageKey, language.code);
    state = state.copyWith(language: language, isLoading: false);
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
