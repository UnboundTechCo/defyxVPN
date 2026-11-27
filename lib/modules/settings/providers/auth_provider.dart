import 'dart:convert';

import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthData {
  final String email;
  final bool isLoggedIn;

  /// Signed in to an Apple guest account, which has no email to show.
  final bool isGuest;

  AuthData({
    required this.email,
    required this.isLoggedIn,
    this.isGuest = false,
  });
}

/// The backend gives Apple guest accounts a placeholder address made from the
/// device id (`<id>@guest.apple.com`). It means nothing to the user.
const _guestEmailSuffix = '@guest.apple.com';

/// The signed-in state for [token]. Only email/password login hands us the
/// address ([storedEmail]), so the email comes from the token's `email` claim,
/// which the backend sets for every customer login except guest mode. That
/// covers code login and Apple, which sends the email on the first login only.
@visibleForTesting
AuthData signedInAuthData(String token, {String storedEmail = ''}) {
  final claims = _tokenClaims(token);
  final claimEmail = claims?['email'];
  final email = claimEmail is String && claimEmail.isNotEmpty
      ? claimEmail
      : storedEmail;

  if (email.toLowerCase().endsWith(_guestEmailSuffix)) {
    return AuthData(email: '', isLoggedIn: true, isGuest: true);
  }

  return AuthData(
    email: email,
    isLoggedIn: true,
    isGuest: email.isEmpty && claims != null,
  );
}

/// The payload of a JWT, without checking its signature: it only decides what
/// to display, and the backend verifies the token on every request.
Map<String, dynamic>? _tokenClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload);
    return claims is Map<String, dynamic> ? claims : null;
  } catch (_) {
    return null;
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthData>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthData> {
  @override
  Future<AuthData> build() async {
    final storage = ref.read(secureStorageProvider);

    final token = await storage.read(premiumTokenKey) ?? '';
    if (token.isEmpty) return AuthData(email: '', isLoggedIn: false);

    final email = await storage.read(premiumEmailKey) ?? '';

    return signedInAuthData(token, storedEmail: email);
  }

  Future<void> login(String email, String token) async {
    final storage = ref.read(secureStorageProvider);

    await storage.write(premiumTokenKey, token);
    await storage.write(premiumEmailKey, email);

    state = AsyncData(signedInAuthData(token, storedEmail: email));
    clear();
  }

  Future<void> loginByCode(String token) async {
    final storage = ref.read(secureStorageProvider);

    await storage.write(premiumTokenKey, token);

    state = AsyncData(signedInAuthData(token));
    clear();
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);

    await storage.delete(premiumTokenKey);
    await storage.delete(premiumEmailKey);
    clear();
    state = AsyncData(AuthData(email: '', isLoggedIn: false));

    // The account's methods go now, not only once a new flowline arrives:
    // signing out offline would otherwise keep them listed and connectable.
    await ref.read(flowlineServiceProvider).dropAccountMethods();
  }

  Future<String> getToken() async {
    final storage = ref.read(secureStorageProvider);

    return await storage.read(premiumTokenKey) ?? '';
  }

  void clear() {
    ref.invalidate(premiumApiServiceProvider);
    ref.invalidate(balanceProvider);
  }

  get isLoggedIn => state.value?.isLoggedIn ?? false;
}
