// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'Defyx VPN';

  @override
  String get headerTitleFirst => '';

  @override
  String get headerTitleRest => 'دیفیکس';

  @override
  String get splashSubtitle =>
      'ساخته‌شده برای دسترسی امن به اینترنت،\nبرای همه، در همه‌جا';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'قطع';

  @override
  String get connecting => 'در حال اتصال';

  @override
  String connectingVia(String groupName) {
    return 'در حال اتصال از طریق $groupName';
  }

  @override
  String get switchingMethod => 'در حال تغییر روش';

  @override
  String get speedTest => 'تست سرعت';

  @override
  String get download => 'دانلود';

  @override
  String get upload => 'آپلود';

  @override
  String get ping => 'پینگ';

  @override
  String get latency => 'تأخیر';

  @override
  String get jitter => 'جیتر';

  @override
  String get packetLoss => 'افت بسته';

  @override
  String get tapHere => 'اینجا ضربه بزنید';

  @override
  String get settings => 'ترجیحات';

  @override
  String get introduction => 'معرفی';

  @override
  String get privacyPolicy => 'سیاست حریم خصوصی';

  @override
  String get termsAndConditions => 'شرایط و ضوابط';

  @override
  String get ourWebsite => 'وب‌سایت ما';

  @override
  String get marketplace => 'فروشگاه';

  @override
  String get telegramBot => 'ربات تلگرام';

  @override
  String get sourceCode => 'کد منبع';

  @override
  String get openSourceLicenses => 'مجوزهای متن‌باز';

  @override
  String get betaCommunity => 'انجمن بتا';

  @override
  String get close => 'بستن';

  @override
  String get copyLogs => 'کپی لاگ‌ها';

  @override
  String get logsCopied => 'لاگ‌ها در کلیپ‌بورد کپی شد';

  @override
  String get appLogs => 'لاگ‌های برنامه';

  @override
  String get autoRefresh => 'تازه‌سازی خودکار';

  @override
  String get clear => 'پاک کردن';

  @override
  String get quickMenu => 'منوی سریع';

  @override
  String get noInternet => 'اینترنت در دسترس نیست';

  @override
  String get error => 'خطا';

  @override
  String get loading => 'در حال بارگیری';

  @override
  String get analyzing => 'در حال بررسی';

  @override
  String get mbps => 'Mbps';

  @override
  String get ms => 'ms';

  @override
  String get language => 'زبان';

  @override
  String get tips => 'نکات';

  @override
  String get english => 'English (انگلیسی)';

  @override
  String get chinese => '中文 (چینی)';

  @override
  String get persian => 'فارسی';

  @override
  String get russian => 'Русский (روسی)';

  @override
  String get gotIt => 'متوجه شدم';

  @override
  String get learnMore => 'بیشتر بدانید';

  @override
  String get defyxGoal =>
      'هدف دیفیکس این است که دسترسی امن به اطلاعات عمومی را تضمین کند و تجربه‌ای آزاد از وب‌گردی فراهم نماید.';

  @override
  String get statusIsChilling => 'در حال استراحت است.';

  @override
  String get statusIs => '';

  @override
  String get statusFailed => 'موفق نشد.';

  @override
  String get statusHas => '';

  @override
  String get statusIsReturning => 'در حال بازگشت';

  @override
  String get statusToStandbyMode => 'به حالت آماده‌به‌کار است.';

  @override
  String get statusPluggingIn => 'در حال اتصال است ...';

  @override
  String get statusPoweredUp => 'روشن و آماده است';

  @override
  String get statusDoingScience => 'مشغول آزمایش است ...';

  @override
  String get statusExitedMatrix => 'از ماتریکس خارج شده';

  @override
  String get statusSorry => 'متأسفیم :(';

  @override
  String get statusConnectAlready => 'همین حالا وصل شوید';

  @override
  String get statusTestingSpeed => 'مشغول تست سرعت است ...';

  @override
  String get statusIsReady => 'برای تست سرعت';

  @override
  String get statusIsInTrouble => 'به دردسر افتاده.';

  @override
  String get statusDXcoreDown => 'DXcore از کار افتاده.';

  @override
  String get statusToSpeedTest => 'آماده است';

  @override
  String get statusYoursToShape => 'در اختیار شماست';

  @override
  String get settingsConnectionMethod => 'روش اتصال';

  @override
  String get settingsEscapeMode => 'حالت عبور از فیلترینگ';

  @override
  String get settingsDestination => 'مقصد';

  @override
  String get settingsSplitTunnel => 'تفکیک ترافیک';

  @override
  String get settingsKillSwitch => 'قطع اضطراری';

  @override
  String get settingsDeepScan => 'اسکن عمیق';

  @override
  String get settingsAutoReconnect => 'اتصال مجدد خودکار';

  @override
  String get settingsIncluded => 'فقط انتخاب‌شده‌ها';

  @override
  String get splitTunnelPreferences => 'ترجیحات';

  @override
  String get splitTunnelModeOff => 'خاموش';

  @override
  String get splitTunnelModeExclude => 'به‌جز موارد انتخاب‌شده';

  @override
  String get splitTunnelModeOnly => 'فقط موارد انتخاب‌شده';

  @override
  String get splitTunnelReconnectNote =>
      'تغییرات تفکیک ترافیک پس از اتصال، یا اتصال مجدد اعمال می‌شود.';

  @override
  String get splitTunnelTabAddresses => 'آدرس‌ها';

  @override
  String get splitTunnelTabApps => 'برنامه‌ها';

  @override
  String get pressBackAgainToExit => 'برای خروج دوباره دکمه بازگشت را بزنید';

  @override
  String get splitTunnelSearch => 'جستجو';

  @override
  String get splitTunnelAddressHint => 'اینجا تایپ کنید ...';

  @override
  String get splitTunnelInvalidDomain =>
      'یک دامنه معتبر وارد کنید، مثلاً example.com';

  @override
  String get splitTunnelInvalidGeoip =>
      'کد کشور، آدرس IP یا محدوده CIDR وارد کنید، مثلاً ir، 8.8.8.8 یا 10.0.0.0/8';

  @override
  String get splitTunnelAppHint => 'مسیر را بنویسید یا انتخاب کنید ...';

  @override
  String get splitTunnelBrowseFile => 'انتخاب فایل';

  @override
  String get splitTunnelBrowseFolder => 'انتخاب پوشه';

  @override
  String get splitTunnelNoApps => 'برنامه‌ای یافت نشد';

  @override
  String get settingsExcluded => 'به‌جز انتخاب‌شده‌ها';

  @override
  String get settingsAtLeastOneCoreRequired =>
      'دست‌کم یک روش اتصال باید فعال بماند';

  @override
  String get settingsResetToDefault => 'بازنشانی';

  @override
  String get settingsDiagnosticsExperiments => 'عیب‌یابی و آزمایش‌ها';

  @override
  String get settingsAutoDetect => 'تشخیص خودکار';

  @override
  String get settingsHapticFeedback => 'بازخورد لمسی';

  @override
  String get offlineFlowlineMessage =>
      'به‌روزرسانی Flowline متوقف شده است، چون اکنون از نسخه‌ی آفلاین استفاده می‌شود.';

  @override
  String get offlineFlowlineUndo => 'برگرداندن';

  @override
  String get updateAvailable => 'به‌روزرسانی موجود است';

  @override
  String get updateRequired => 'به‌روزرسانی الزامی است';

  @override
  String get updateOptionalMessage =>
      'برای استفاده بهتر از برنامه و لذت بردن از آخرین بهبودها، لطفاً به جدیدترین نسخه به‌روزرسانی کنید.';

  @override
  String get updateRequiredMessage =>
      'برای ادامه استفاده از دیفیکس، لطفاً به آخرین نسخه به‌روزرسانی کنید. این به‌روزرسانی شامل بهبودهای مهم است و برای عملکرد برنامه ضروری است.';

  @override
  String get updateNow => 'به‌روزرسانی';

  @override
  String get notNow => 'بعداً';

  @override
  String get updateMethods => 'به‌روزرسانی روش‌ها';

  @override
  String get importConfig => 'وارد کردن کانفیگ';

  @override
  String get synchronization => 'همگام‌سازی';

  @override
  String get settingsDonation => 'حمایت مالی';

  @override
  String get settingsDonationDescription =>
      'به ما کمک کنید دیوارهای سانسور دیجیتال و فیلترینگ اینترنت را فرو بریزیم.';

  @override
  String get settingsTrainingCenter => 'مرکز آموزش';

  @override
  String get settingsTrainingCenterDescription =>
      'نحوه استفاده از دیفیکس را از طریق آموزش‌های یوتیوب ما بیاموزید.';

  @override
  String get authenticationRequired => 'احراز هویت لازم است';

  @override
  String get premiumLoginDescription =>
      'برای دسترسی به اشتراک‌های پریمیوم خود، باید از طریق وب‌سایت دیفیکس وارد حساب خود شوید یا حساب جدیدی بسازید.';

  @override
  String get email => 'ایمیل';

  @override
  String get emailHint => 'example@domain.com';

  @override
  String get emailValidation => 'لطفاً ایمیل خود را وارد کنید';

  @override
  String get password => 'رمز عبور';

  @override
  String get passwordHint => 'رمز عبور خود را وارد کنید';

  @override
  String get passwordValidation => 'لطفاً رمز عبور خود را وارد کنید';

  @override
  String get passwordMinLength => 'رمز عبور باید حداقل ۶ کاراکتر باشد';

  @override
  String get login => 'ورود';

  @override
  String get noAccount => 'حساب کاربری ندارید؟';

  @override
  String get signUp => 'ثبت‌نام';

  @override
  String get loginFailed =>
      'ورود ناموفق بود. لطفاً اطلاعات ورود خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get loginSuccess => 'با موفقیت وارد شدید!';

  @override
  String get code => 'کد';

  @override
  String get codeHint => 'کد دسترسی خود را وارد کنید';

  @override
  String get codeValidation => 'لطفاً کد خود را وارد کنید';

  @override
  String get premiumLoginByCodeDescription =>
      'برای دسترسی به اشتراک‌های پریمیوم خود، کد دسترسی‌ای را که دریافت کرده‌اید وارد کنید.';

  @override
  String get havingTrouble => 'مشکل دارید؟';

  @override
  String get signedInAs => 'ایمیلی که با آن وارد شده‌اید:';

  @override
  String get premiumImportDescription =>
      'اگر به‌دلیل محدودیت‌های اینترنت، اشتراک‌های پریمیوم شما بارگیری نمی‌شود و با روش‌های موجود هم نمی‌توانید متصل شوید، می‌توانید فایلی را که از فروشگاه گرفته‌اید در برنامه وارد کنید.';

  @override
  String get planningToExit => 'قصد خروج دارید؟';

  @override
  String get signOut => 'خروج از حساب';

  @override
  String get signOutSuccess => 'با موفقیت از حساب خارج شدید!';

  @override
  String get cancel => 'انصراف';

  @override
  String get deleteAccount => 'حذف حساب کاربری';

  @override
  String get deleteAccountConfirmation =>
      'این کار حساب شما را برای همیشه حذف می‌کند و قابل بازگشت نیست. ادامه می‌دهید؟';

  @override
  String get deleteAccountSuccess => 'حساب کاربری با موفقیت حذف شد.';

  @override
  String get deleteAccountFailed => 'حذف حساب کاربری ناموفق بود';

  @override
  String get settingsMarketplace => 'پریمیوم';

  @override
  String get marketplaceDescription =>
      'دسترسی VPN پریمیوم با\nاتصال سریع و پایدار.';

  @override
  String get loggedIn => 'وارد شده‌اید';

  @override
  String get loginOrRegister => 'ورود یا ثبت‌نام';

  @override
  String get loginByCode => 'ورود با کد';

  @override
  String get backToLoginByEmail => 'بازگشت به ورود با ایمیل';

  @override
  String get connectionRequired => 'اتصال لازم است';

  @override
  String get connectionRequiredDescription =>
      'برای اینکه ورود یا ثبت‌نام به‌صورت امن انجام شود، ابتدا باید با یکی از روش‌های اتصال موجود متصل شوید.';

  @override
  String get speedTestFailed => 'تست سرعت ناموفق بود. لطفاً دوباره تلاش کنید.';

  @override
  String get speedTestConnectionUnstable =>
      'اتصال شما کند یا ناپایدار به نظر می‌رسد.';

  @override
  String get tvHoldOkToReorder => 'برای جابه‌جایی، دکمه OK را نگه دارید';

  @override
  String get tvMoveModeHint => 'با ▲ ▼ جابه‌جا کنید · OK برای پایان';

  @override
  String get privateDnsTitle => 'DNS خصوصی روشن است';

  @override
  String privateDnsMessage(String host) {
    return 'گوشی شما درخواست‌های DNS را به $host می‌فرستد. اگر هنگام اتصال سایت‌ها باز نمی‌شوند، در تنظیمات شبکه، DNS خصوصی را روی «خودکار» یا «خاموش» بگذارید.';
  }

  @override
  String get privateDnsOpenSettings => 'باز کردن تنظیمات';

  @override
  String get privateDnsDismiss => 'بعداً';

  @override
  String get marketplaceInfoDescription =>
      'این اشتراک پریمیوم مستقیماً از دیفیکس خریداری شده است.';

  @override
  String get marketplaceInfoRemainingData => 'حجم باقی‌مانده';

  @override
  String get marketplaceInfoRemainingTime => 'زمان باقی‌مانده';

  @override
  String get marketplaceInfoGigabytes => 'گیگابایت';

  @override
  String get marketplaceInfoDays => 'روز';

  @override
  String get marketplaceInfoUsageError =>
      'دریافت میزان مصرف ممکن نشد. اتصال خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get marketplaceInfoRetry => 'تلاش دوباره';

  @override
  String get marketplaceInfoJumpDescription => 'تغییر سرور، بدون تغییر موقعیت.';

  @override
  String get marketplaceInfoJump => 'پرش';

  @override
  String get marketplaceInfoJumpSuccess => 'سرور با موفقیت تغییر کرد.';

  @override
  String get marketplaceInfoJumpFailed => 'تغییر سرور ممکن نشد';

  @override
  String get jumpDisconnectTitle => 'VPN قطع می‌شود';

  @override
  String get jumpDisconnectMessage =>
      'با تغییر سرور، VPN شما قطع می‌شود. ادامه می‌دهید؟';

  @override
  String get jumpDisconnectConfirm => 'بله، سرور را تغییر بده';

  @override
  String get privacyNoticeTitle => 'اطلاعیه حریم خصوصی';

  @override
  String get privacyNoticeIntro => 'دیفیکس چه چیزهایی را به کجا می‌فرستد:';

  @override
  String get privacyNoticeConnection =>
      'هنگام باز شدن برنامه و هنگام اتصال، تنظیمات اتصال دریافت می‌شود و ارائه‌دهنده اینترنت شما از روی نشانی IP شناسایی می‌شود؛ این کار از طریق سرورهای دیفیکس و سرویس‌های شناسایی IP مانند freeipapi.com و ip.sb انجام می‌شود. هنگام ورود به حساب پریمیوم، اطلاعات حساب شما ارسال می‌شود.';

  @override
  String get privacyNoticeTelemetry =>
      'فقط اگر در پایین اجازه دهید: آمار استفاده و گزارش‌های خرابی به Google Firebase ارسال می‌شود. این داده‌ها شامل نام ارائه‌دهنده اینترنت شما، روش اتصال و کشور خروجی VPN است.';

  @override
  String get privacyNoticeAds =>
      'تبلیغات از Google AdMob نمایش داده می‌شود که ممکن است برای شخصی‌سازی آن‌ها از شما رضایت بخواهد.';

  @override
  String get privacyNoticeSpeedTest =>
      'هنگام اجرای تست سرعت، نتایج آن به Cloudflare ارسال می‌شود.';

  @override
  String get privacyNoticeOwnTraffic =>
      'هنگام اتصال VPN، برنامه اتصال‌های خودش را هم از طریق آن می‌فرستد، به جز اتصال‌هایی که خود VPN را برقرار می‌کنند.';

  @override
  String get privacyNoticeLocal =>
      'نام ارائه‌دهنده اینترنت شما همچنین روی همین دستگاه نگه داشته می‌شود تا اتصال‌های بعدی سریع‌تر برقرار شوند.';

  @override
  String get privacyNoticeChangeLater =>
      'هر زمان می‌توانید این انتخاب را در ترجیحات، بخش «عیب‌یابی و آزمایش‌ها»، تغییر دهید.';

  @override
  String get privacyNoticeVpnProfile =>
      'با ادامه، با نصب پروفایل VPN موافقت می‌کنید.';

  @override
  String get privacyNoticeShareDiagnostics =>
      'ارسال آمار استفاده و گزارش‌های خرابی';

  @override
  String get privacyNoticeGotIt => 'متوجه شدم';

  @override
  String get settingsShareDiagnostics => 'ارسال داده‌های عیب‌یابی';

  @override
  String get adTapToLearnMore => 'برای اطلاعات بیشتر ضربه بزنید';

  @override
  String get adClickToLearnMore => 'برای اطلاعات بیشتر کلیک کنید';

  @override
  String get premiumTitle => 'پریمیوم';

  @override
  String get premiumTabAccount => 'حساب کاربری';

  @override
  String get premiumTabPlans => 'پلن‌ها';

  @override
  String get premiumTabWallet => 'کیف پول';

  @override
  String get premiumTabSupport => 'پشتیبانی';

  @override
  String get selectPlanDuration =>
      'مدت پلنی که می‌خواهید خریداری کنید را انتخاب کنید:';

  @override
  String creditsPrice(String price) {
    return '$price اعتبار';
  }

  @override
  String get choose => 'انتخاب';

  @override
  String get payNow => 'پرداخت';

  @override
  String get whatYoullGet => 'چه چیزی دریافت می‌کنید';

  @override
  String get months => 'ماه';

  @override
  String get subscriptionSuccess => 'اشتراک پلن با موفقیت انجام شد!';

  @override
  String get selectTopUpAmount => 'لطفاً مبلغ شارژ کیف پول را انتخاب کنید:';

  @override
  String get paymentSuccessful => 'پرداخت موفق بود';

  @override
  String get walletToppedUp => 'کیف پول شما شارژ شد';

  @override
  String get continueAction => 'ادامه';

  @override
  String get purchaseCredits => 'خرید اعتبار';

  @override
  String get back => 'بازگشت';

  @override
  String get selectAmount => 'لطفاً یک مبلغ انتخاب کنید';

  @override
  String get balance => 'موجودی';

  @override
  String get topUp => 'شارژ';

  @override
  String get registerToAccessPremium =>
      'برای دسترسی به امکانات پریمیوم باید ثبت‌نام کنید.';

  @override
  String get continueWithApple => 'ادامه با Apple';

  @override
  String get goToLoginSection => 'رفتن به بخش ورود';

  @override
  String get easyLogin => 'ورود آسان';

  @override
  String get needHelp => 'به کمک نیاز دارید؟';

  @override
  String get supportContactDescription =>
      'از طریق راه‌های ارتباطی زیر با تیم پشتیبانی ما در تماس باشید:';

  @override
  String get telegram => 'تلگرام';

  @override
  String get website => 'وب‌سایت';

  @override
  String get settingsMethodsPremium => 'پریمیوم';

  @override
  String get settingsMethodsMarket => 'فروشگاه';

  @override
  String get settingsMethodsBuiltIn => 'پیش‌فرض';

  @override
  String get settingsMethodsRewards => 'جوایز';

  @override
  String settingsMethodsOnCount(int active, int total) {
    return '$active از $total';
  }

  @override
  String settingsMethodsBySeller(String seller) {
    return 'از $seller';
  }

  @override
  String settingsMethodsDaysLeft(int days) {
    return '$days روز مانده';
  }

  @override
  String get settingsMethodsExpired => 'منقضی شده';
}
