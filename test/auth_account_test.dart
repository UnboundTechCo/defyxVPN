import 'dart:convert';

import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// A token shaped like the backend's customer JWTs. The signature is never
/// checked by the app, so a dummy one is enough.
String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

void main() {
  group('signedInAuthData', () {
    test('email/password login shows the typed email', () {
      final token = _jwt({'email': 'user@example.com', 'sub': 7});

      final auth = signedInAuthData(token, storedEmail: 'user@example.com');

      expect(auth.isLoggedIn, isTrue);
      expect(auth.email, 'user@example.com');
      expect(auth.isGuest, isFalse);
    });

    test('code login shows the email from the token', () {
      final token = _jwt({'email': 'code@example.com', 'sub': 7});

      final auth = signedInAuthData(token);

      expect(auth.email, 'code@example.com');
      expect(auth.isGuest, isFalse);
    });

    test('Apple login without an email from Apple uses the token email', () {
      final token = _jwt({'email': 'abc@privaterelay.appleid.com', 'sub': 7});

      final auth = signedInAuthData(token, storedEmail: '');

      expect(auth.email, 'abc@privaterelay.appleid.com');
      expect(auth.isGuest, isFalse);
    });

    test('guest mode token has no email and is a guest', () {
      final token = _jwt({'sub': 7, 'role': 'customer'});

      final auth = signedInAuthData(token);

      expect(auth.email, isEmpty);
      expect(auth.isGuest, isTrue);
    });

    test('code login into a guest account hides the placeholder address', () {
      final token = _jwt({'email': 'ABC-123@guest.apple.com', 'sub': 7});

      final auth = signedInAuthData(token);

      expect(auth.email, isEmpty);
      expect(auth.isGuest, isTrue);
    });

    test('a token that is not a JWT falls back to the stored email', () {
      expect(
        signedInAuthData('opaque', storedEmail: 'user@example.com').email,
        'user@example.com',
      );

      final auth = signedInAuthData('opaque');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.email, isEmpty);
      expect(auth.isGuest, isFalse);
    });
  });
}
