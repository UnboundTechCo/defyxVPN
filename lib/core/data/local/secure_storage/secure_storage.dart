import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_interface.dart';

final secureStorageProvider = Provider<ISecureStorage>((ref) {
  if (Platform.isWindows) {
    return WindowsSecureStorage();
  }
  final storage = ref.watch(flutterSecureStorageProvider);
  return SecureStorage(storage);
});

final class WindowsSecureStorage implements ISecureStorage {
  static const String _prefix = 'secure_';

  @override
  Future<void> write(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString('$_prefix$key', value);
      debugPrint(
          'WindowsSecureStorage.write($key): success=$success, length=${value.length}');
    } catch (e) {
      debugPrint('Error writing to Windows storage: $e');
      rethrow;
    }
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> map) async {
    try {
      final jsonString = jsonEncode(map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonString);
    } catch (e) {
      debugPrint('Error saving map to Windows storage: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> readMap(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_prefix$key');
      if (jsonString == null) {
        return {};
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading map from Windows storage: $e');
      return {};
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      // Reload to get fresh data after app restart
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final value = prefs.getString('$_prefix$key');
      // debugPrint(
      //     'WindowsSecureStorage.read($key): hasValue=${value != null}, length=${value?.length ?? 0}');
      return value;
    } catch (e) {
      debugPrint('Error reading from Windows storage: $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (e) {
      debugPrint('Error deleting from Windows storage: $e');
      rethrow;
    }
  }
}

/// Default secure storage for non-Windows platforms
final class SecureStorage implements ISecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing to secure storage: $e');
      rethrow;
    }
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> map) async {
    try {
      final jsonString = jsonEncode(map);
      await _storage.write(key: key, value: jsonString);
    } catch (e) {
      debugPrint('Error saving map: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> readMap(String key) async {
    try {
      final jsonString = await _storage.read(key: key);
      if (jsonString == null) {
        return {};
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading map: $e');
      return {};
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error reading from secure storage (key: $key): $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting from secure storage: $e');
      rethrow;
    }
  }
}
