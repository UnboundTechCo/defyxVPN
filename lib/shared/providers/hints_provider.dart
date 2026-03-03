import 'dart:convert';
import 'package:defyx_vpn/common/dtos/hint.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
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

// Provider that loads ALL hints from flowline API
final selectedHintsProvider = FutureProvider<List<Hint>>((ref) async {
  final secureStorage = ref.watch(secureStorageProvider);
  
  debugPrint('Loading hints from secure storage...');
  
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
    return allHints;
  } catch (e) {
    // On any error, return default hints
    debugPrint('Error loading hints: $e');
    return _defaultHints;
  }
});
