import 'dart:convert';
import 'package:defyx_vpn/common/dtos/hint.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Default fallback hints
final _defaultHints = [
  const Hint(
    title: 'Hello 👋',
    message:
        'DEFYX can provide you with a safer and more private browsing experience.',
  ),
  const Hint(
    title: null,
    message:
        'It\'s recommended to protect your sensitive information and stay cautious about the websites you visit.',
  ),
];

// Helper function to apply translation to a hint based on locale
Hint _applyTranslation(Hint hint, String localeCode) {
  // If no translations or no translation for this locale, return original hint
  if (hint.translate == null || !hint.translate!.containsKey(localeCode)) {
    return hint;
  }
  
  try {
    final translation = hint.translate![localeCode];
    if (translation is Map<String, dynamic>) {
      final translatedTitle = translation['title'] as String?;
      final translatedDesc = translation['desc'] as String?;
      
      // Return hint with translated content, fallback to original if translation is missing
      return hint.copyWith(
        title: translatedTitle ?? hint.title,
        message: translatedDesc ?? hint.message,
      );
    }
  } catch (e) {
    debugPrint('Error applying translation: $e');
  }
  
  return hint;
}

// Provider that loads ALL hints from flowline API
final selectedHintsProvider = FutureProvider<List<Hint>>((ref) async {
  final secureStorage = ref.watch(secureStorageProvider);
  final languageState = ref.watch(languageProvider);
  final currentLocale = languageState.language.code;
  
  debugPrint('Loading hints from secure storage...');
  debugPrint('Using locale: $currentLocale');
  
  try {
    // Try to read tips from secure storage
    final hintsJson = await secureStorage.read(apiTipsKey);
    
    debugPrint('Hints JSON from storage: $hintsJson');
    
    if (hintsJson == null || hintsJson.isEmpty) {
      debugPrint('No hints in storage, using defaults');
      return _defaultHints;
    }
    
    // Parse hints from JSON
    final List<dynamic> hintsData = json.decode(hintsJson);
    debugPrint('Parsed ${hintsData.length} hints from JSON');
    
    final List<Hint> allHints = hintsData
        .map((json) => Hint.fromJson(json as Map<String, dynamic>))
        .toList();
    
    debugPrint('Converted to ${allHints.length} Hint objects');
    
    // If no hints or empty list, use defaults
    if (allHints.isEmpty) {
      debugPrint('Hints list is empty, using defaults');
      return _defaultHints;
    }
    
    debugPrint('Returning ${allHints.length} hints from API');
    
    // Apply translations based on current locale
    final localizedHints = allHints.map((hint) => _applyTranslation(hint, currentLocale)).toList();
    debugPrint('Applied translations for locale: $currentLocale');
    
    return localizedHints;
  } catch (e) {
    // On any error, return default hints
    debugPrint('Error loading hints: $e');
    return _defaultHints;
  }
});
