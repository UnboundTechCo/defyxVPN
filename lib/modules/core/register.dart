import 'dart:io';

import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  Future<bool> registerByApple() async {
    final credential = await _authorizeByApple();
    if (credential == null) {
      return false;
    }

    final authorizationCode = credential.authorizationCode;

    final premiumApiService = await ref.read(premiumApiServiceProvider.future);
    final result = await premiumApiService
        .loginByApple(authorizationCode)
        .then((result) async {
          final authService = ref.read(authProvider.notifier);

          await authService.login(credential.email ?? "", result.access_token);
          return true;
        })
        .catchError((error) {
          ToastUtil.showToast(error.toString());
          return false;
        });
    return result;
  }

  Future<bool> guestModeLoginApple() async {
    final uniqueIdentifier = await getAppleDeviceId();
    if (uniqueIdentifier == null) {
      return false;
    }

    final premiumApiService = await ref.read(premiumApiServiceProvider.future);
    final result = await premiumApiService
        .guestModeLoginApple(uniqueIdentifier)
        .then((result) async {
          final authService = ref.read(authProvider.notifier);

          await authService.login("", result.access_token);
          return true;
        })
        .catchError((error) {
          ToastUtil.showToast(error.toString());
          return false;
        });
    return result;
  }

  Future<String?> _getIosDeviceId() async {
    final info = await DeviceInfoPlugin().iosInfo;
    return info.identifierForVendor;
  }

  Future<String?> _getMacDeviceId() async {
    final info = await DeviceInfoPlugin().macOsInfo;
    return info.systemGUID;
  }

  Future<String?> getAppleDeviceId() async {
    final isApple = Platform.isIOS || Platform.isMacOS;
    if (isApple) {
      if (Platform.isIOS) {
        return await _getIosDeviceId();
      } else if (Platform.isMacOS) {
        return await _getMacDeviceId();
      }
    }
    return null;
  }
}
