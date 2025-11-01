import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlobalVars {
  static const String appBuildType = 'googlePlay';

  static String get appStore => dotenv.env['APP_STORE_LINK'] ?? '';
  static String get testFlight => dotenv.env['TEST_FLIGHT_LINK'] ?? '';
  static String get github => dotenv.env['GITHUB_LINK'] ?? '';
  static String get googlePlay => dotenv.env['GOOGLE_PLAY_LINK'] ?? '';
}
