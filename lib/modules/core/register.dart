import 'dart:io';

import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

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

  /// Platforms that can open a guest account from the device ID, and so buy
  /// credits and plans without signing up first.
  static bool get supportsGuestLogin =>
      Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

  /// Signs in to the guest account tied to this device, creating it on first
  /// use.
  Future<bool> guestModeLogin() async {
    final uniqueIdentifier = await getDeviceId();
    if (uniqueIdentifier == null || uniqueIdentifier.isEmpty) {
      return false;
    }

    final premiumApiService = await ref.read(premiumApiServiceProvider.future);
    final login = Platform.isAndroid
        ? premiumApiService.guestModeLoginAndroid(uniqueIdentifier)
        : premiumApiService.guestModeLoginApple(uniqueIdentifier);
    final result = await login
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

  Future<String?> _getAndroidDeviceId() async {
    const androidIdPlugin = AndroidId();
    final String? androidId = await androidIdPlugin.getId();
    return androidId;
  }

  Future<String?> getDeviceId() async {
    if (Platform.isIOS) {
      return await _getIosDeviceId();
    } else if (Platform.isMacOS) {
      return await _getMacDeviceId();
    } else if (Platform.isAndroid) {
      return await _getAndroidDeviceId();
    }
    return null;
  }
}
