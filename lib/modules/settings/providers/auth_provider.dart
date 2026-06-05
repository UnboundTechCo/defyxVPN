import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider =
    AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final storage = ref.read(secureStorageProvider);

    final token = await storage.read(premiumTokenKey);

    return token?.isNotEmpty ?? false;
  }

  Future<void> login(String token) async {
    final storage = ref.read(secureStorageProvider);

    await storage.write(premiumTokenKey, token);

    state = const AsyncData(true);
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);

    await storage.delete(premiumTokenKey);

    state = const AsyncData(false);
  }

  Future<String> getToken() async {
    final storage = ref.read(secureStorageProvider);

    return await storage.read(premiumTokenKey) ??"";
  }
}