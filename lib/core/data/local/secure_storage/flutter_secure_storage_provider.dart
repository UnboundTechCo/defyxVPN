import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  const MacOsOptions macOSOptions = MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  return FlutterSecureStorage(aOptions: androidOptions, iOptions: iosOptions,mOptions: macOSOptions);
});
