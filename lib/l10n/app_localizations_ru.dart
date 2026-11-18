// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Defyx VPN';

  @override
  String get splashSubtitle =>
      'Создан для безопасного доступа в интернет,\nразработан для всех, везде';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get connecting => 'Подключение';

  @override
  String connectingVia(String groupName) {
    return 'ПОДКЛЮЧЕНИЕ ЧЕРЕЗ $groupName';
  }

  @override
  String get switchingMethod => 'ПЕРЕКЛЮЧЕНИЕ МЕТОДА';

  @override
  String get speedTest => 'Тест скорости';

  @override
  String get download => 'ЗАГРУЗКА';

  @override
  String get upload => 'ВЫГРУЗКА';

  @override
  String get ping => 'ПИНГ';

  @override
  String get latency => 'ЗАДЕРЖКА';

  @override
  String get jitter => 'ДЖИТТЕР';

  @override
  String get packetLoss => 'ПОТЕРЯ ПАКЕТОВ';

  @override
  String get tapHere => 'НАЖМИТЕ ЗДЕСЬ';

  @override
  String get settings => 'Настройки';

  @override
  String get introduction => 'Введение';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get termsAndConditions => 'Условия использования';

  @override
  String get ourWebsite => 'Наш веб-сайт';

  @override
  String get marketplace => 'Магазин';

  @override
  String get telegramBot => 'Телеграм-бот';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get openSourceLicenses => 'Лицензии с открытым исходным кодом';

  @override
  String get betaCommunity => 'Бета-сообщество';

  @override
  String get close => 'Закрыть';

  @override
  String get copyLogs => 'Копировать логи';

  @override
  String get logsCopied => 'Логи скопированы в буфер обмена';

  @override
  String get appLogs => 'Логи приложения';

  @override
  String get autoRefresh => 'Автообновление';

  @override
  String get clear => 'Очистить';

  @override
  String get quickMenu => 'Быстрое меню';

  @override
  String get noInternet => 'Нет интернета';

  @override
  String get error => 'Ошибка';

  @override
  String get loading => 'Загрузка';

  @override
  String get analyzing => 'Анализ';

  @override
  String get mbps => 'Мбит/с';

  @override
  String get ms => 'мс';

  @override
  String get language => 'Язык';

  @override
  String get tips => 'СОВЕТЫ';

  @override
  String get english => 'English (Английский)';

  @override
  String get chinese => '中文 (Китайский)';

  @override
  String get persian => 'فارسی (Персидский)';

  @override
  String get russian => 'Русский';

  @override
  String get gotIt => 'Понятно';

  @override
  String get learnMore => 'УЗНАТЬ БОЛЬШЕ';

  @override
  String get defyxGoal =>
      'Цель Defyx — обеспечить безопасный доступ к общедоступной информации и предоставить бесплатный просмотр.';

  @override
  String get statusIsChilling => 'отдыхает.';

  @override
  String get statusIs => 'это';

  @override
  String get statusFailed => 'не удалось.';

  @override
  String get statusHas => 'имеет';

  @override
  String get statusIsReturning => 'возвращается';

  @override
  String get statusToStandbyMode => 'в режим ожидания.';

  @override
  String get statusPluggingIn => 'подключение ...';

  @override
  String get statusPoweredUp => 'включен';

  @override
  String get statusDoingScience => 'выполняется работа ...';

  @override
  String get statusExitedMatrix => 'вышел из матрицы';

  @override
  String get statusSorry => 'нам очень жаль :(';

  @override
  String get statusConnectAlready => 'Подключиться сейчас';

  @override
  String get statusTestingSpeed => 'тестирование скорости ...';

  @override
  String get statusIsReady => 'готов';

  @override
  String get statusIsInTrouble => 'в беде.';

  @override
  String get statusDXcoreDown => 'DXcore недоступен.';

  @override
  String get statusToSpeedTest => 'к тесту скорости';

  @override
  String get statusYoursToShape => 'создан для вас';

  @override
  String get settingsConnectionMethod => 'МЕТОД ПОДКЛЮЧЕНИЯ';

  @override
  String get settingsEscapeMode => 'РЕЖИМ ОБХОДА';

  @override
  String get settingsDestination => 'НАЗНАЧЕНИЕ';

  @override
  String get settingsSplitTunnel => 'РАЗДЕЛЬНОЕ ТУННЕЛИРОВАНИЕ';

  @override
  String get settingsKillSwitch => 'АВАРИЙНОЕ ОТКЛЮЧЕНИЕ';

  @override
  String get settingsDeepScan => 'ГЛУБОКОЕ СКАНИРОВАНИЕ';

  @override
  String get settingsHealthCheck => 'МОНИТОРИНГ СОСТОЯНИЯ';

  @override
  String get settingsIncluded => 'ВКЛЮЧЕНО';

  @override
  String get splitTunnelPreferences => 'Настройки';

  @override
  String get splitTunnelModeOff => 'ВЫКЛ';

  @override
  String get splitTunnelModeExclude => 'ИСКЛЮЧИТЬ ВЫБРАННЫЕ';

  @override
  String get splitTunnelModeOnly => 'ТОЛЬКО ВЫБРАННЫЕ';

  @override
  String get splitTunnelReconnectNote =>
      'изменения настроек раздельного туннелирования вступят в силу после подключения или переподключения.';

  @override
  String get splitTunnelTabAddresses => 'АДРЕСА';

  @override
  String get splitTunnelTabApps => 'ПРИЛОЖЕНИЯ';

  @override
  String get pressBackAgainToExit => 'Нажмите «Назад» ещё раз, чтобы выйти';

  @override
  String get splitTunnelSearch => 'Поиск';

  @override
  String get splitTunnelAddressHint => 'введите здесь ...';

  @override
  String get splitTunnelInvalidDomain =>
      'введите корректный домен, например example.com';

  @override
  String get splitTunnelInvalidGeoip =>
      'введите код страны, IP-адрес или диапазон CIDR, например ir, 8.8.8.8 или 10.0.0.0/8';

  @override
  String get splitTunnelAppHint => 'введите или выберите путь ...';

  @override
  String get splitTunnelBrowseFile => 'Выбрать файл';

  @override
  String get splitTunnelBrowseFolder => 'Выбрать папку';

  @override
  String get splitTunnelNoApps => 'Приложения не найдены';

  @override
  String get settingsExcluded => 'ИСКЛЮЧЕНО';

  @override
  String get settingsAtLeastOneCoreRequired =>
      'Должен оставаться включенным хотя бы один модуль';

  @override
  String get settingsResetToDefault => 'Сброс';

  @override
  String get settingsDiagnosticsExperiments => 'Диагностика и эксперименты';

  @override
  String get settingsAutoDetect => 'Автоопределение';

  @override
  String get settingsHapticFeedback => 'Тактильная отдача';

  @override
  String get offlineFlowlineMessage =>
      'Обновления Flowline приостановлены, так как используется автономная версия.';

  @override
  String get offlineFlowlineUndo => 'ОТМЕНИТЬ';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get updateRequired => 'Требуется обновление';

  @override
  String get updateOptionalMessage =>
      'Чтобы получить максимум от приложения и насладиться последними улучшениями, пожалуйста, обновитесь до новейшей версии.';

  @override
  String get updateRequiredMessage =>
      'Для продолжения использования Defyx, пожалуйста, обновитесь до последней версии. Это обновление включает критические улучшения и необходимо для работы приложения.';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get notNow => 'Не сейчас';

  @override
  String get updateMethods => 'Обновить методы';

  @override
  String get importConfig => 'Импорт конфигурации';

  @override
  String get synchronization => 'Синхронизация';

  @override
  String get settingsDonation => 'Пожертвование';

  @override
  String get settingsDonationDescription =>
      'Помогите нам разрушить стены цифровой цензуры и интернет-фильтрации.';

  @override
  String get authenticationRequired => 'Требуется аутентификация';

  @override
  String get premiumLoginDescription =>
      'Для доступа к вашим премиум-подпискам вам необходимо войти в систему или создать учетную запись на веб-сайте Defyx.';

  @override
  String get email => 'Электронная почта';

  @override
  String get emailHint => 'example@domain.com';

  @override
  String get emailValidation =>
      'Пожалуйста, введите ваш адрес электронной почты';

  @override
  String get password => 'Пароль';

  @override
  String get passwordHint => 'Введите ваш пароль';

  @override
  String get passwordValidation => 'Пожалуйста, введите ваш пароль';

  @override
  String get passwordMinLength => 'Пароль должен содержать не менее 6 символов';

  @override
  String get login => 'Войти';

  @override
  String get noAccount => 'Нет учетной записи?';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get loginFailed =>
      'Ошибка входа. Проверьте свои учетные данные и попробуйте снова.';

  @override
  String get loginSuccess => 'Вход выполнен успешно!';

  @override
  String get code => 'Код';

  @override
  String get codeHint => 'Введите ваш код доступа';

  @override
  String get codeValidation => 'Пожалуйста, введите ваш код';

  @override
  String get premiumLoginByCodeDescription =>
      'Для доступа к вашим премиум-подпискам введите предоставленный вам код доступа.';

  @override
  String get havingTrouble => 'Возникли проблемы?';

  @override
  String get signedInAs =>
      'Вы в настоящее время вошли в систему с адресом электронной почты';

  @override
  String get premiumImportDescription =>
      'Если ваши премиум-подписки не могут быть загружены из-за ограничений интернета и вы не можете подключиться доступными методами, вы можете импортировать файл, полученный из Маркетплейса, в приложение.';

  @override
  String get planningToExit => 'Планируете выйти?';

  @override
  String get signOut => 'Выйти';

  @override
  String get signOutSuccess => 'Выход выполнен успешно!';

  @override
  String get cancel => 'Отмена';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmation =>
      'Ваш аккаунт будет удален навсегда. Это действие нельзя отменить. Продолжить?';

  @override
  String get deleteAccountSuccess => 'Аккаунт успешно удален.';

  @override
  String get deleteAccountFailed => 'Не удалось удалить аккаунт';

  @override
  String get settingsMarketplace => 'PREMIUM';

  @override
  String get marketplaceDescription =>
      'Получите премиум-доступ к VPN с\nбыстрыми и надежными подключениями.';

  @override
  String get loggedIn => 'ВОШЛИ В СИСТЕМУ';

  @override
  String get loginOrRegister => 'ВОЙТИ ИЛИ ЗАРЕГИСТРИРОВАТЬСЯ';

  @override
  String get loginByCode => 'Войти по коду';

  @override
  String get backToLoginByEmail => 'Вернуться к входу по электронной почте';

  @override
  String get connectionRequired => 'Требуется подключение';

  @override
  String get connectionRequiredDescription =>
      'Чтобы завершить безопасный процесс входа или регистрации, вы должны сначала установить соединение, используя один из доступных методов подключения.';

  @override
  String get speedTestFailed =>
      'Тест скорости не удался. Пожалуйста, попробуйте снова.';

  @override
  String get speedTestConnectionUnstable =>
      'Похоже, ваше соединение медленное или нестабильное.';

  @override
  String get tvHoldOkToReorder => 'Удерживайте OK, чтобы изменить порядок';

  @override
  String get tvMoveModeHint => '▲ ▼ — переместить · OK — готово';

  @override
  String get privateDnsTitle => 'Включён персональный DNS-сервер';

  @override
  String privateDnsMessage(String host) {
    return 'Телефон отправляет DNS-запросы на $host. Если при подключении сайты не открываются, выберите для персонального DNS-сервера «Автоматический режим» или «Отключено» в настройках сети.';
  }

  @override
  String get privateDnsOpenSettings => 'Открыть настройки';

  @override
  String get privateDnsDismiss => 'Не сейчас';

  @override
  String get marketplaceInfoDescription =>
      'Эта премиум-подписка была приобретена напрямую у Defyx.';

  @override
  String get marketplaceInfoRemainingData => 'Осталось трафика';

  @override
  String get marketplaceInfoRemainingTime => 'Осталось времени';

  @override
  String get marketplaceInfoGigabytes => 'ГБ';

  @override
  String get marketplaceInfoDays => 'дн.';

  @override
  String get marketplaceInfoUsageError =>
      'Не удалось загрузить данные об использовании. Проверьте соединение и повторите попытку.';

  @override
  String get marketplaceInfoRetry => 'Повторить';

  @override
  String get marketplaceInfoJumpDescription =>
      'Смените сервер, не меняя локацию.';

  @override
  String get marketplaceInfoJump => 'Сменить';

  @override
  String get marketplaceInfoJumpSuccess => 'Сервер успешно изменён.';

  @override
  String get marketplaceInfoJumpFailed => 'Не удалось сменить сервер';

  @override
  String get jumpDisconnectTitle => 'VPN будет отключён';

  @override
  String get jumpDisconnectMessage =>
      'При смене сервера VPN отключится. Продолжить?';

  @override
  String get jumpDisconnectConfirm => 'Да, сменить сервер';
  String get privacyNoticeTitle => 'Уведомление о конфиденциальности';

  @override
  String get privacyNoticeIntro => 'Что отправляет DefyxVPN и куда:';

  @override
  String get privacyNoticeConnection =>
      '• При запуске приложения и при подключении загружаются настройки подключения, а ваш интернет-провайдер определяется по IP-адресу — через серверы DefyxVPN и службы определения IP, например freeipapi.com и ip.sb. При входе в Premium отправляются данные вашей учётной записи.';

  @override
  String get privacyNoticeTelemetry =>
      '• Только если вы разрешите это ниже: статистика использования и отчёты о сбоях отправляются в Google Firebase. Они включают название вашего интернет-провайдера, способ подключения и страну выхода VPN.';

  @override
  String get privacyNoticeAds =>
      '• Реклама предоставляется Google AdMob, который может запросить ваше согласие на её персонализацию.';

  @override
  String get privacyNoticeSpeedTest =>
      '• Результаты теста скорости отправляются в Cloudflare, когда вы запускаете тест.';

  @override
  String get privacyNoticeOwnTraffic =>
      '• Пока VPN подключён, приложение направляет через него и собственные соединения, кроме тех, которые устанавливают сам VPN.';

  @override
  String get privacyNoticeLocal =>
      'Название вашего интернет-провайдера также хранится на этом устройстве, чтобы ускорить последующие подключения.';

  @override
  String get privacyNoticeChangeLater =>
      'Вы можете изменить свой выбор в любое время в настройках.';

  @override
  String get privacyNoticeVpnProfile =>
      'Продолжая, вы соглашаетесь установить профиль VPN.';

  @override
  String get privacyNoticeShareDiagnostics =>
      'Отправлять статистику использования и отчёты о сбоях';

  @override
  String get privacyNoticeGotIt => 'Понятно';

  @override
  String get settingsPrivacy => 'КОНФИДЕНЦИАЛЬНОСТЬ';

  @override
  String get settingsShareDiagnostics => 'ОТПРАВКА ДИАГНОСТИКИ';
}
