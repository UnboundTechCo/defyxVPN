import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlobalVars {
  static const String appBuildType = 'googlePlay';

  static String get appStore => dotenv.env['LINK_APP_STORE'] ?? '';
  static String get testFlight => dotenv.env['LINK_TEST_FLIGHT'] ?? '';
  static String get github => dotenv.env['LINK_GITHUB'] ?? '';
  static String get googlePlay => dotenv.env['LINK_GOOGLE_PLAY'] ?? '';
}
