import 'dart:convert';

import 'package:defyx_vpn/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage_interface.dart';

final secureStorageProvider = Provider<ISecureStorage>((ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  return SecureStorage(storage);
});

final class SecureStorage implements ISecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
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
        debugPrint('No data found for key: $key');
        return {};
      }

      final Map<String, dynamic> map = jsonDecode(jsonString);
      return map;
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
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      rethrow;
    }
  }
}
