import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthData {
  final String email;
  final bool isLoggedIn;

  AuthData({required this.email, required this.isLoggedIn});
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthData>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthData> {
  @override
  Future<AuthData> build() async {
    final storage = ref.read(secureStorageProvider);

    final token = await storage.read(premiumTokenKey);
    final email = await storage.read(premiumEmailKey) ?? '';

    return AuthData(email: email, isLoggedIn: token?.isNotEmpty ?? false);
  }

  Future<void> login(String email, String token) async {
    final storage = ref.read(secureStorageProvider);

    await storage.write(premiumTokenKey, token);
    await storage.write(premiumEmailKey, email);

    state = AsyncData(AuthData(email: email, isLoggedIn: true));
  }

  Future<void> loginByCode(String token) async {
    final storage = ref.read(secureStorageProvider);

    await storage.write(premiumTokenKey, token);

    state = AsyncData(AuthData(email: "", isLoggedIn: true));
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);

    await storage.delete(premiumTokenKey);
    await storage.delete(premiumEmailKey);

    state = AsyncData(AuthData(email: '', isLoggedIn: false));
  }

  Future<String> getToken() async {
    final storage = ref.read(secureStorageProvider);

    return await storage.read(premiumTokenKey) ?? '';
  }
}
