import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class Register {
  final WidgetRef ref;

  Register({required this.ref});
  Future<AuthorizationCredentialAppleID?> _authorizeByApple() async {
    try {
      return await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> registerByApple() async {
    final credential = await _authorizeByApple();
    if (credential == null) {
      return;
    }

    final authorizationCode = credential.authorizationCode;

    final premiumApiService = await ref.read(premiumApiServiceProvider.future);
    final result = await premiumApiService.loginByApple(authorizationCode);

    final authService = ref.read(authProvider.notifier);

    await authService.login(credential.email ?? "", result.access_token);
  }
}
