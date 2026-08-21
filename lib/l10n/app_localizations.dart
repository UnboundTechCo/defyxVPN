import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Defyx VPN'**
  String get appTitle;

  /// Subtitle shown on splash screen
  ///
  /// In en, this message translates to:
  /// **'Crafted for secure internet access,\ndesigned for everyone, everywhere'**
  String get splashSubtitle;

  /// Connect button text
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Disconnect button text
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Connected status text
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Disconnected status text
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Connecting status text
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// Connecting status with group name
  ///
  /// In en, this message translates to:
  /// **'CONNECTING VIA {groupName}'**
  String connectingVia(String groupName);

  /// Status shown when switching connection method
  ///
  /// In en, this message translates to:
  /// **'SWITCHING METHOD'**
  String get switchingMethod;

  /// Speed test feature label
  ///
  /// In en, this message translates to:
  /// **'Speed Test'**
  String get speedTest;

  /// Download speed label
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get download;

  /// Upload speed label
  ///
  /// In en, this message translates to:
  /// **'UPLOAD'**
  String get upload;

  /// Ping label
  ///
  /// In en, this message translates to:
  /// **'PING'**
  String get ping;

  /// Latency label
  ///
  /// In en, this message translates to:
  /// **'LATENCY'**
  String get latency;

  /// Jitter label
  ///
  /// In en, this message translates to:
  /// **'JITTER'**
  String get jitter;

  /// Packet loss label
  ///
  /// In en, this message translates to:
  /// **'P.LOSS'**
  String get packetLoss;

  /// Instruction to tap to start speed test
  ///
  /// In en, this message translates to:
  /// **'TAP HERE'**
  String get tapHere;

  /// Settings menu label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Introduction menu item
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get introduction;

  /// Privacy policy menu item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms and conditions menu item
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// Our website menu item
  ///
  /// In en, this message translates to:
  /// **'Our Website'**
  String get ourWebsite;

  /// Marketplace menu item
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// Telegram bot menu item
  ///
  /// In en, this message translates to:
  /// **'Telegram Bot'**
  String get telegramBot;

  /// Source code link
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// Open source licenses link
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// Beta community link
  ///
  /// In en, this message translates to:
  /// **'Beta Community'**
  String get betaCommunity;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Copy logs button text
  ///
  /// In en, this message translates to:
  /// **'Copy Logs'**
  String get copyLogs;

  /// Message shown when logs are copied
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get logsCopied;

  /// App logs panel title
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get appLogs;

  /// Auto-refresh toggle label
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh'**
  String get autoRefresh;

  /// Clear logs button text
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Quick menu label
  ///
  /// In en, this message translates to:
  /// **'Quick Menu'**
  String get quickMenu;

  /// No internet connection status
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get noInternet;

  /// Error status
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Loading status
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Analyzing status
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get analyzing;

  /// Megabits per second unit
  ///
  /// In en, this message translates to:
  /// **'Mbps'**
  String get mbps;

  /// Milliseconds unit
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get ms;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Tips section header
  ///
  /// In en, this message translates to:
  /// **'TIPS'**
  String get tips;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Chinese language name
  ///
  /// In en, this message translates to:
  /// **'中文 (Chinese)'**
  String get chinese;

  /// Got it button text
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// Learn more section title
  ///
  /// In en, this message translates to:
  /// **'LEARN MORE'**
  String get learnMore;

  /// Description of Defyx goal
  ///
  /// In en, this message translates to:
  /// **'The goal of Defyx is to ensure secure access to public information and provide a free browsing experience.'**
  String get defyxGoal;

  /// Status message - chilling state
  ///
  /// In en, this message translates to:
  /// **'is chilling.'**
  String get statusIsChilling;

  /// Status connector word
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get statusIs;

  /// Status message - failed state
  ///
  /// In en, this message translates to:
  /// **'failed.'**
  String get statusFailed;

  /// Status connector word
  ///
  /// In en, this message translates to:
  /// **'has'**
  String get statusHas;

  /// Status message - returning state
  ///
  /// In en, this message translates to:
  /// **'is returning'**
  String get statusIsReturning;

  /// Status message - standby mode text
  ///
  /// In en, this message translates to:
  /// **'to standby mode.'**
  String get statusToStandbyMode;

  /// Status message - plugging in state
  ///
  /// In en, this message translates to:
  /// **'plugging in ...'**
  String get statusPluggingIn;

  /// Status message - powered up state
  ///
  /// In en, this message translates to:
  /// **'powered up'**
  String get statusPoweredUp;

  /// Status message - working state
  ///
  /// In en, this message translates to:
  /// **'doing science ...'**
  String get statusDoingScience;

  /// Status message - disconnected state
  ///
  /// In en, this message translates to:
  /// **'exited the matrix'**
  String get statusExitedMatrix;

  /// Status message - apology
  ///
  /// In en, this message translates to:
  /// **'we\'re sorry :('**
  String get statusSorry;

  /// Status message - connect prompt
  ///
  /// In en, this message translates to:
  /// **'Connect already'**
  String get statusConnectAlready;

  /// Status message - speed test in progress
  ///
  /// In en, this message translates to:
  /// **'testing speed ...'**
  String get statusTestingSpeed;

  /// Status message - ready state
  ///
  /// In en, this message translates to:
  /// **'is ready'**
  String get statusIsReady;

  /// Status connector word when DXcore handshake fails
  ///
  /// In en, this message translates to:
  /// **'is in trouble.'**
  String get statusIsInTrouble;

  /// Status message shown when DXcore cannot be verified
  ///
  /// In en, this message translates to:
  /// **'DXcore down.'**
  String get statusDXcoreDown;

  /// Status message - ready for speed test
  ///
  /// In en, this message translates to:
  /// **'to speed test'**
  String get statusToSpeedTest;

  /// Settings status message
  ///
  /// In en, this message translates to:
  /// **'yours to shape'**
  String get statusYoursToShape;

  /// Settings section - connection method
  ///
  /// In en, this message translates to:
  /// **'CONNECTION METHOD'**
  String get settingsConnectionMethod;

  /// Settings section - escape mode
  ///
  /// In en, this message translates to:
  /// **'ESCAPE MODE'**
  String get settingsEscapeMode;

  /// Settings section - destination
  ///
  /// In en, this message translates to:
  /// **'DESTINATION'**
  String get settingsDestination;

  /// Settings section - split tunnel
  ///
  /// In en, this message translates to:
  /// **'SPLIT TUNNEL'**
  String get settingsSplitTunnel;

  /// Settings section - kill switch
  ///
  /// In en, this message translates to:
  /// **'KILL SWITCH'**
  String get settingsKillSwitch;

  /// Settings section - deep scan
  ///
  /// In en, this message translates to:
  /// **'DEEP SCAN'**
  String get settingsDeepScan;

  /// Settings section - health check
  ///
  /// In en, this message translates to:
  /// **'HEALTH CHECK'**
  String get settingsHealthCheck;

  /// Settings label - included items
  ///
  /// In en, this message translates to:
  /// **'INCLUDED'**
  String get settingsIncluded;

  /// Settings error message - core requirement
  ///
  /// In en, this message translates to:
  /// **'At least one core must remain enabled'**
  String get settingsAtLeastOneCoreRequired;

  /// Settings button - reset to default
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get settingsResetToDefault;

  /// Offline flowline notification message
  ///
  /// In en, this message translates to:
  /// **'Flowline updates have been paused because the offline version is currently being used.'**
  String get offlineFlowlineMessage;

  /// Offline flowline undo button
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get offlineFlowlineUndo;

  /// Update dialog title - optional update
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// Update dialog title - mandatory update
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// Update dialog message - optional update
  ///
  /// In en, this message translates to:
  /// **'To get the most out of the app and enjoy the latest improvements, please update to the newest version.'**
  String get updateOptionalMessage;

  /// Update dialog message - mandatory update
  ///
  /// In en, this message translates to:
  /// **'To continue using Defyx, please update to the latest version. This update includes critical improvements and is required for app functionality.'**
  String get updateRequiredMessage;

  /// Update dialog button - update action
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// Update dialog button - dismiss action
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// Sync menu - update methods option
  ///
  /// In en, this message translates to:
  /// **'Update Methods'**
  String get updateMethods;

  /// Sync menu - import configuration file option
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get importConfig;

  /// Sync menu label
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get synchronization;

  /// Donation widget title
  ///
  /// In en, this message translates to:
  /// **'Donation'**
  String get settingsDonation;

  /// Donation widget description text
  ///
  /// In en, this message translates to:
  /// **'Help us break down the walls of digital censorship and internet filtering.'**
  String get settingsDonationDescription;

  /// Premium login dialog title
  ///
  /// In en, this message translates to:
  /// **'Authentication Required'**
  String get authenticationRequired;

  /// Premium login dialog description
  ///
  /// In en, this message translates to:
  /// **'To access your Premium subscription(s), you need to login or create an account through the Defyx website.'**
  String get premiumLoginDescription;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Email field hint text
  ///
  /// In en, this message translates to:
  /// **'example@domain.com'**
  String get emailHint;

  /// Email validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailValidation;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Password field hint text
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Password validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordValidation;

  /// Password minimum length validation error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Sign up prompt text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// Sign up link text
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// Login failed toast message
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try again.'**
  String get loginFailed;

  /// Login success toast message
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccess;

  /// Code field label
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// Code field hint text
  ///
  /// In en, this message translates to:
  /// **'Enter your access code'**
  String get codeHint;

  /// Code validation error message
  ///
  /// In en, this message translates to:
  /// **'Please enter your code'**
  String get codeValidation;

  /// Premium login by code dialog description
  ///
  /// In en, this message translates to:
  /// **'To access your Premium subscription(s), enter the access code provided to you.'**
  String get premiumLoginByCodeDescription;

  /// Premium trouble dialog title
  ///
  /// In en, this message translates to:
  /// **'Having trouble?'**
  String get havingTrouble;

  /// Premium trouble dialog - signed in message prefix
  ///
  /// In en, this message translates to:
  /// **'You are currently signed in with the email address'**
  String get signedInAs;

  /// Premium trouble dialog - import instructions
  ///
  /// In en, this message translates to:
  /// **'If your Premium subscriptions cannot be loaded due to internet restrictions and you\'re unable to connect using the available methods, you can import the file obtained from the Marketplace into the app.'**
  String get premiumImportDescription;

  /// Premium trouble dialog - sign out prompt
  ///
  /// In en, this message translates to:
  /// **'Planning to exit?'**
  String get planningToExit;

  /// Sign out link text
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Sign out success toast message
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully!'**
  String get signOutSuccess;

  /// Premium widget - marketplace title
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get settingsMarketplace;

  /// Premium widget - marketplace description
  ///
  /// In en, this message translates to:
  /// **'Browse secure VPN configurations from trusted suppliers.'**
  String get marketplaceDescription;

  /// Premium widget - logged in status
  ///
  /// In en, this message translates to:
  /// **'LOGGED IN'**
  String get loggedIn;

  /// Premium widget - login/register prompt
  ///
  /// In en, this message translates to:
  /// **'LOGIN OR REGISTER'**
  String get loginOrRegister;

  /// Login by code button text
  ///
  /// In en, this message translates to:
  /// **'Login by code'**
  String get loginByCode;

  /// Back to email login button text
  ///
  /// In en, this message translates to:
  /// **'Back to login by email'**
  String get backToLoginByEmail;

  /// Connection required dialog title
  ///
  /// In en, this message translates to:
  /// **'Connection Required'**
  String get connectionRequired;

  /// Connection required dialog description
  ///
  /// In en, this message translates to:
  /// **'To complete a secure login or registration process, you must first establish a connection using one of the available connection methods.'**
  String get connectionRequiredDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
