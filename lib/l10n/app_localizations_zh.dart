// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Defyx VPN';

  @override
  String get headerTitleFirst => 'D';

  @override
  String get headerTitleRest => 'efyx';

  @override
  String get splashSubtitle => '为安全的互联网访问而设计，\n为所有人，在任何地方';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get connecting => '正在连接';

  @override
  String connectingVia(String groupName) {
    return '正在通过 $groupName 连接';
  }

  @override
  String get switchingMethod => '切换方式中';

  @override
  String get speedTest => '速度测试';

  @override
  String get download => '下载';

  @override
  String get upload => '上传';

  @override
  String get ping => 'Ping';

  @override
  String get latency => '延迟';

  @override
  String get jitter => '抖动';

  @override
  String get packetLoss => '丢包';

  @override
  String get tapHere => '点击这里';

  @override
  String get settings => '设置';

  @override
  String get introduction => '介绍';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsAndConditions => '条款和条件';

  @override
  String get ourWebsite => '我们的网站';

  @override
  String get marketplace => '商店';

  @override
  String get telegramBot => 'Telegram 机器人';

  @override
  String get sourceCode => '源代码';

  @override
  String get openSourceLicenses => '开源许可证';

  @override
  String get betaCommunity => '测试社区';

  @override
  String get close => '关闭';

  @override
  String get copyLogs => '复制日志';

  @override
  String get logsCopied => '日志已复制到剪贴板';

  @override
  String get appLogs => '应用日志';

  @override
  String get autoRefresh => '自动刷新';

  @override
  String get clear => '清除';

  @override
  String get quickMenu => '快速菜单';

  @override
  String get noInternet => '无网络连接';

  @override
  String get error => '错误';

  @override
  String get loading => '加载中';

  @override
  String get analyzing => '分析中';

  @override
  String get mbps => 'Mbps';

  @override
  String get ms => '毫秒';

  @override
  String get language => '语言';

  @override
  String get tips => '提示';

  @override
  String get english => 'English (英语)';

  @override
  String get chinese => '中文';

  @override
  String get persian => '波斯语';

  @override
  String get russian => '俄语';

  @override
  String get gotIt => '知道了';

  @override
  String get learnMore => '了解更多';

  @override
  String get defyxGoal => 'Defyx 的目标是确保安全地获取公共信息，并提供自由的浏览体验。';

  @override
  String get statusIsChilling => '正在休息。';

  @override
  String get statusIs => '';

  @override
  String get statusFailed => '失败了。';

  @override
  String get statusHas => '';

  @override
  String get statusIsReturning => '正在返回';

  @override
  String get statusToStandbyMode => '待机模式。';

  @override
  String get statusPluggingIn => '连接中 ...';

  @override
  String get statusPoweredUp => '已启动';

  @override
  String get statusDoingScience => '正在工作 ...';

  @override
  String get statusExitedMatrix => '已退出矩阵';

  @override
  String get statusSorry => '我们很抱歉 :(';

  @override
  String get statusConnectAlready => '立即连接';

  @override
  String get statusTestingSpeed => '正在测速 ...';

  @override
  String get statusIsReady => '已准备好';

  @override
  String get statusIsInTrouble => '遇到麻烦了。';

  @override
  String get statusDXcoreDown => 'DXcore 出故障了。';

  @override
  String get statusToSpeedTest => '进行速度测试';

  @override
  String get statusYoursToShape => '任您定制';

  @override
  String get settingsConnectionMethod => '连接方式';

  @override
  String get settingsEscapeMode => '流量控制';

  @override
  String get settingsDestination => '目的地';

  @override
  String get settingsSplitTunnel => '拆分隧道';

  @override
  String get settingsKillSwitch => '终止开关';

  @override
  String get settingsDeepScan => '深度扫描';

  @override
  String get settingsAutoReconnect => '自动重连';

  @override
  String get settingsIncluded => '已包含';

  @override
  String get splitTunnelPreferences => '偏好设置';

  @override
  String get splitTunnelModeOff => '关闭';

  @override
  String get splitTunnelModeExclude => '排除所选';

  @override
  String get splitTunnelModeOnly => '仅限所选';

  @override
  String get splitTunnelReconnectNote => '分流设置的更改将在连接或重新连接后生效。';

  @override
  String get splitTunnelTabAddresses => '地址';

  @override
  String get splitTunnelTabApps => '应用';

  @override
  String get pressBackAgainToExit => '再按一次返回键退出';

  @override
  String get splitTunnelSearch => '搜索';

  @override
  String get splitTunnelAddressHint => '在此输入 ...';

  @override
  String get splitTunnelInvalidDomain => '请输入有效的域名，例如 example.com';

  @override
  String get splitTunnelInvalidGeoip =>
      '请输入国家代码、IP 地址或 CIDR 范围，例如 ir、8.8.8.8 或 10.0.0.0/8';

  @override
  String get splitTunnelAppHint => '输入或选择路径 ...';

  @override
  String get splitTunnelBrowseFile => '选择文件';

  @override
  String get splitTunnelBrowseFolder => '选择文件夹';

  @override
  String get splitTunnelNoApps => '未找到应用';

  @override
  String get settingsExcluded => '已排除';

  @override
  String get settingsAtLeastOneCoreRequired => '至少需要启用一种连接方式';

  @override
  String get settingsResetToDefault => '重置';

  @override
  String get settingsDiagnosticsExperiments => '诊断与实验';

  @override
  String get settingsAutoDetect => '自动检测';

  @override
  String get settingsHapticFeedback => '触感反馈';

  @override
  String get offlineFlowlineMessage => '由于当前使用离线版本，Flowline更新已暂停。';

  @override
  String get offlineFlowlineUndo => '撤销';

  @override
  String get updateAvailable => '可用更新';

  @override
  String get updateRequired => '需要更新';

  @override
  String get updateOptionalMessage => '为了充分利用应用程序并享受最新改进，请更新到最新版本。';

  @override
  String get updateRequiredMessage =>
      '要继续使用 Defyx，请更新到最新版本。此更新包含关键改进，对应用功能必不可少。';

  @override
  String get updateNow => '立即更新';

  @override
  String get notNow => '暂不更新';

  @override
  String get updateMethods => '更新方法';

  @override
  String get importConfig => '导入配置';

  @override
  String get synchronization => '同步';

  @override
  String get settingsDonation => '捐赠';

  @override
  String get settingsDonationDescription => '帮助我们打破数字审查和互联网过滤的壁垒。';

  @override
  String get settingsTrainingCenter => '培训中心';

  @override
  String get settingsTrainingCenterDescription =>
      '通过我们的 YouTube 教程学习如何使用 DefyxVPN。';

  @override
  String get authenticationRequired => '需要身份验证';

  @override
  String get premiumLoginDescription => '要访问您的高级订阅，您需要通过 Defyx 网站登录或创建账户。';

  @override
  String get email => '电子邮件';

  @override
  String get emailHint => 'example@domain.com';

  @override
  String get emailValidation => '请输入您的电子邮件';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '输入您的密码';

  @override
  String get passwordValidation => '请输入您的密码';

  @override
  String get passwordMinLength => '密码至少需要6个字符';

  @override
  String get login => '登录';

  @override
  String get noAccount => '没有账户？';

  @override
  String get signUp => '注册';

  @override
  String get loginFailed => '登录失败。请检查您的凭据并重试。';

  @override
  String get loginSuccess => '登录成功！';

  @override
  String get code => '代码';

  @override
  String get codeHint => '输入您的访问代码';

  @override
  String get codeValidation => '请输入您的代码';

  @override
  String get premiumLoginByCodeDescription => '要访问您的高级订阅，请输入提供给您的访问代码。';

  @override
  String get havingTrouble => '遇到问题？';

  @override
  String get signedInAs => '您当前登录所用的邮箱地址为';

  @override
  String get premiumImportDescription =>
      '如果由于网络限制无法加载您的高级订阅，且无法通过现有连接方式连接，您可以将从商店获取的文件导入应用。';

  @override
  String get planningToExit => '打算退出？';

  @override
  String get signOut => '退出';

  @override
  String get signOutSuccess => '退出成功！';

  @override
  String get cancel => '取消';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountConfirmation => '这将永久删除您的账户且无法撤销。是否继续？';

  @override
  String get deleteAccountSuccess => '账户已成功删除。';

  @override
  String get deleteAccountFailed => '删除账户失败';

  @override
  String get settingsMarketplace => 'PREMIUM';

  @override
  String get marketplaceDescription => '获得快速可靠的高级\nVPN访问权限。';

  @override
  String get loggedIn => '已登录';

  @override
  String get loginOrRegister => '登录或注册';

  @override
  String get loginByCode => '使用代码登录';

  @override
  String get backToLoginByEmail => '返回电子邮件登录';

  @override
  String get connectionRequired => '需要连接';

  @override
  String get connectionRequiredDescription =>
      '要完成安全的登录或注册过程，您必须首先使用可用的连接方法之一建立连接。';

  @override
  String get speedTestFailed => '速度测试失败，请重试。';

  @override
  String get speedTestConnectionUnstable => '您的网络连接似乎较慢或不稳定。';

  @override
  String get tvHoldOkToReorder => '长按 OK 键调整顺序';

  @override
  String get tvMoveModeHint => '▲ ▼ 移动 · OK 完成';

  @override
  String get privateDnsTitle => '已开启私人 DNS';

  @override
  String privateDnsMessage(String host) {
    return '您的手机会将 DNS 查询发送到 $host。如果连接后网站无法打开，请在网络设置中将私人 DNS 设为“自动”或“关闭”。';
  }

  @override
  String get privateDnsOpenSettings => '打开设置';

  @override
  String get privateDnsDismiss => '以后再说';

  @override
  String get marketplaceInfoDescription => '此高级订阅直接购自 Defyx。';

  @override
  String get marketplaceInfoRemainingData => '剩余流量';

  @override
  String get marketplaceInfoRemainingTime => '剩余时间';

  @override
  String get marketplaceInfoGigabytes => 'GB';

  @override
  String get marketplaceInfoDays => '天';

  @override
  String get marketplaceInfoUsageError => '无法加载用量信息。请检查网络连接后重试。';

  @override
  String get marketplaceInfoRetry => '重试';

  @override
  String get marketplaceInfoJumpDescription => '在不更改位置的情况下切换服务器。';

  @override
  String get marketplaceInfoJump => '切换';

  @override
  String get marketplaceInfoJumpSuccess => '服务器切换成功。';

  @override
  String get marketplaceInfoJumpFailed => '无法切换服务器';

  @override
  String get jumpDisconnectTitle => 'VPN 将断开连接';

  @override
  String get jumpDisconnectMessage => '切换服务器会断开您的 VPN。是否继续？';

  @override
  String get jumpDisconnectConfirm => '是，切换服务器';

  @override
  String get privacyNoticeTitle => '隐私声明';

  @override
  String get privacyNoticeIntro => 'DefyxVPN 发送哪些数据以及发送到哪里：';

  @override
  String get privacyNoticeConnection =>
      '应用启动和连接时，会获取连接设置，并根据您的 IP 地址识别您的网络服务提供商，所用的是 DefyxVPN 的服务器以及 freeipapi.com、ip.sb 等 IP 查询服务。登录高级版时会发送您的账户信息。';

  @override
  String get privacyNoticeTelemetry =>
      '仅在您于下方允许时：使用统计和崩溃报告会发送至 Google Firebase，其中包括您的网络服务提供商名称、连接方式以及 VPN 出口所在国家。';

  @override
  String get privacyNoticeAds => '广告由 Google AdMob 提供，它可能会征求您对个性化广告的同意。';

  @override
  String get privacyNoticeSpeedTest => '运行测速时，测速结果会发送至 Cloudflare。';

  @override
  String get privacyNoticeOwnTraffic =>
      'VPN 连接期间，应用自身的连接也会经过 VPN，建立 VPN 本身的连接除外。';

  @override
  String get privacyNoticeLocal => '您的网络服务提供商名称还会保存在本设备上，以加快之后的连接。';

  @override
  String get privacyNoticeChangeLater => '您可以随时在“设置”>“诊断与实验”中更改此选择。';

  @override
  String get privacyNoticeVpnProfile => '继续即表示您同意安装 VPN 配置文件。';

  @override
  String get privacyNoticeShareDiagnostics => '发送使用统计和崩溃报告';

  @override
  String get privacyNoticeGotIt => '知道了';

  @override
  String get settingsShareDiagnostics => '发送诊断数据';

  @override
  String get adTapToLearnMore => '点按了解更多';

  @override
  String get adClickToLearnMore => '点击了解更多';

  @override
  String get premiumTitle => '高级版';

  @override
  String get premiumTabAccount => '账户';

  @override
  String get premiumTabPlans => '套餐';

  @override
  String get premiumTabWallet => '钱包';

  @override
  String get premiumTabSupport => '支持';

  @override
  String get selectPlanDuration => '请选择您要购买的套餐时长：';

  @override
  String creditsPrice(String price) {
    return '$price 点数';
  }

  @override
  String get choose => '选择';

  @override
  String get payNow => '立即支付';

  @override
  String get whatYoullGet => '您将获得';

  @override
  String get months => '个月';

  @override
  String get subscriptionSuccess => '套餐订阅成功！';

  @override
  String get selectTopUpAmount => '请选择钱包充值金额：';

  @override
  String get paymentSuccessful => '支付成功';

  @override
  String get walletToppedUp => '您的钱包已充值';

  @override
  String get continueAction => '继续';

  @override
  String get purchaseCredits => '购买点数';

  @override
  String get back => '返回';

  @override
  String get selectAmount => '请选择金额';

  @override
  String get balance => '余额';

  @override
  String get topUp => '充值';

  @override
  String get registerToAccessPremium => '您需要注册才能使用高级功能。';

  @override
  String get continueWithApple => '通过 Apple 继续';

  @override
  String get goToLoginSection => '前往登录';

  @override
  String get easyLogin => '快速登录';

  @override
  String get needHelp => '需要帮助？';

  @override
  String get supportContactDescription => '请通过以下渠道联系我们的支持团队：';

  @override
  String get telegram => 'Telegram';

  @override
  String get website => '网站';

  @override
  String get settingsMethodsPremium => '高级';

  @override
  String get settingsMethodsMarket => '商店';

  @override
  String get settingsMethodsBuiltIn => '内置';

  @override
  String get settingsMethodsRewards => '奖励';

  @override
  String settingsMethodsOnCount(int active, int total) {
    return '已开启 $active/$total';
  }

  @override
  String settingsMethodsBySeller(String seller) {
    return '由 $seller 提供';
  }

  @override
  String settingsMethodsDaysLeft(int days) {
    return '剩余 $days 天';
  }

  @override
  String get settingsMethodsExpired => '已过期';
}
