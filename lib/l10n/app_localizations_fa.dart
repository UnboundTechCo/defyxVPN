// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'دیفکس وی‌پی‌ان';

  @override
  String get splashSubtitle =>
      'برای دسترسی امن به اینترنت طراحی شده،\nبرای همه، در همه جا';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get connected => 'متصل شد';

  @override
  String get disconnected => 'قطع شد';

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
  String get latency => 'تاخیر';

  @override
  String get jitter => 'لرزش';

  @override
  String get packetLoss => 'از دست دادن بسته';

  @override
  String get tapHere => 'اینجا ضربه بزنید';

  @override
  String get settings => 'تنظیمات';

  @override
  String get introduction => 'معرفی';

  @override
  String get privacyPolicy => 'سیاست حفظ حریم خصوصی';

  @override
  String get termsAndConditions => 'شرایط و ضوابط';

  @override
  String get ourWebsite => 'وب‌سایت ما';

  @override
  String get marketplace => 'فروشگاه';

  @override
  String get telegramBot => 'بات تلگرام';

  @override
  String get sourceCode => 'کد منبع';

  @override
  String get openSourceLicenses => 'مجوزهای منبع باز';

  @override
  String get betaCommunity => 'انجمن بتا';

  @override
  String get close => 'بستن';

  @override
  String get copyLogs => 'کپی گزارش‌ها';

  @override
  String get logsCopied => 'گزارش‌ها در کلیپ‌بورد کپی شدند';

  @override
  String get appLogs => 'گزارش‌های برنامه';

  @override
  String get autoRefresh => 'به‌روزرسانی خودکار';

  @override
  String get clear => 'پاک کردن';

  @override
  String get quickMenu => 'منوی سریع';

  @override
  String get noInternet => 'اینترنت موجود نیست';

  @override
  String get error => 'خطا';

  @override
  String get loading => 'در حال بارگیری';

  @override
  String get analyzing => 'در حال تحلیل';

  @override
  String get mbps => 'مگابیت بر ثانیه';

  @override
  String get ms => 'میلی‌ثانیه';

  @override
  String get language => 'زبان';

  @override
  String get tips => 'نکات';

  @override
  String get english => 'English (انگلیسی)';

  @override
  String get chinese => '中文 (چینی)';

  @override
  String get gotIt => 'متوجه شدم';

  @override
  String get learnMore => 'بیشتر بدانید';

  @override
  String get defyxGoal =>
      'هدف دیفکس اطمینان از دسترسی امن به اطلاعات عمومی و ارائه تجربه مرور رایگان است.';

  @override
  String get statusIsChilling => 'در حال استراحت است.';

  @override
  String get statusIs => 'است';

  @override
  String get statusFailed => 'ناموفق بود.';

  @override
  String get statusHas => 'دارد';

  @override
  String get statusIsReturning => 'در حال بازگشت است';

  @override
  String get statusToStandbyMode => 'به حالت آماده باش.';

  @override
  String get statusPluggingIn => 'در حال اتصال ...';

  @override
  String get statusPoweredUp => 'روشن شد';

  @override
  String get statusDoingScience => 'در حال انجام کار ...';

  @override
  String get statusExitedMatrix => 'از ماتریکس خارج شد';

  @override
  String get statusSorry => 'متاسفیم :(';

  @override
  String get statusConnectAlready => 'الان متصل شوید';

  @override
  String get statusTestingSpeed => 'تست سرعت در جریان است ...';

  @override
  String get statusIsReady => 'آماده است';

  @override
  String get statusIsInTrouble => 'به مشکل خورده.';

  @override
  String get statusDXcoreDown => 'DXcore متوقف شده.';

  @override
  String get statusToSpeedTest => 'برای تست سرعت';

  @override
  String get statusYoursToShape => 'برای شما طراحی شده';

  @override
  String get settingsConnectionMethod => 'روش اتصال';

  @override
  String get settingsEscapeMode => 'حالت فرار';

  @override
  String get settingsDestination => 'مقصد';

  @override
  String get settingsSplitTunnel => 'تونل تقسیم شده';

  @override
  String get settingsKillSwitch => 'کلید قطع';

  @override
  String get settingsDeepScan => 'اسکن عمیق';

  @override
  String get settingsHealthCheck => 'بررسی سلامت';

  @override
  String get settingsIncluded => 'شامل شده';

  @override
  String get settingsAtLeastOneCoreRequired =>
      'حداقل یک هسته باید فعال باقی بماند';

  @override
  String get settingsResetToDefault => 'بازنشانی';

  @override
  String get offlineFlowlineMessage =>
      'به‌روزرسانی‌های Flowline متوقف شده‌اند زیرا نسخه آفلاین در حال استفاده است.';

  @override
  String get offlineFlowlineUndo => 'لغو';

  @override
  String get updateAvailable => 'به‌روزرسانی موجود است';

  @override
  String get updateRequired => 'به‌روزرسانی الزامی است';

  @override
  String get updateOptionalMessage =>
      'برای استفاده بهتر از برنامه و لذت بردن از آخرین بهبودها، لطفاً به جدیدترین نسخه به‌روزرسانی کنید.';

  @override
  String get updateRequiredMessage =>
      'برای ادامه استفاده از Defyx، لطفاً به آخرین نسخه به‌روزرسانی کنید. این به‌روزرسانی شامل بهبودهای مهم است و برای عملکرد برنامه ضروری است.';

  @override
  String get updateNow => 'اکنون به‌روزرسانی کنید';

  @override
  String get notNow => 'الان نه';

  @override
  String get updateMethods => 'به‌روزرسانی روش‌ها';

  @override
  String get importConfig => 'وارد کردن پیکربندی';

  @override
  String get synchronization => 'همگام‌سازی';

  @override
  String get settingsDonation => 'کمک مالی';

  @override
  String get settingsDonationDescription =>
      'به ما کمک کنید تا دیوارهای سانسور دیجیتال و فیلترینگ اینترنت را از بین ببریم.';

  @override
  String get authenticationRequired => 'احراز هویت لازم است';

  @override
  String get premiumLoginDescription =>
      'برای دسترسی به اشتراک پرمیوم خود، باید از طریق وب‌سایت Defyx وارد شوید یا حساب کاربری ایجاد کنید.';

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
  String get signUp => 'ثبت نام';

  @override
  String get loginFailed =>
      'ورود ناموفق بود. لطفاً اطلاعات ورود خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get loginSuccess => 'ورود موفقیت‌آمیز بود!';

  @override
  String get code => 'کد';

  @override
  String get codeHint => 'کد دسترسی خود را وارد کنید';

  @override
  String get codeValidation => 'لطفاً کد خود را وارد کنید';

  @override
  String get premiumLoginByCodeDescription =>
      'برای دسترسی به اشتراک پرمیوم خود، کد دسترسی ارائه شده به شما را وارد کنید.';

  @override
  String get havingTrouble => 'مشکل دارید؟';

  @override
  String get signedInAs => 'شما در حال حاضر با آدرس ایمیل';

  @override
  String get premiumImportDescription =>
      'اگر اشتراک‌های پرمیوم شما به دلیل محدودیت‌های اینترنتی قابل بارگذاری نیستند و نمی‌توانید با روش‌های موجود متصل شوید، می‌توانید فایل دریافتی از فروشگاه را در برنامه وارد کنید.';

  @override
  String get planningToExit => 'قصد خروج دارید؟';

  @override
  String get signOut => 'خروج';

  @override
  String get signOutSuccess => 'خروج موفقیت‌آمیز بود!';

  @override
  String get settingsMarketplace => 'فروشگاه';

  @override
  String get marketplaceDescription =>
      'پیکربندی‌های امن VPN را از تامین‌کنندگان قابل اعتماد مرور کنید.';

  @override
  String get loggedIn => 'وارد شده';

  @override
  String get loginOrRegister => 'ورود یا ثبت نام';

  @override
  String get loginByCode => 'ورود با کد';

  @override
  String get backToLoginByEmail => 'بازگشت به ورود با ایمیل';

  @override
  String get connectionRequired => 'اتصال لازم است';

  @override
  String get connectionRequiredDescription =>
      'برای تکمیل فرآیند امن ورود یا ثبت‌نام، ابتدا باید با استفاده از یکی از روش‌های اتصال موجود، اتصال برقرار کنید.';
}
