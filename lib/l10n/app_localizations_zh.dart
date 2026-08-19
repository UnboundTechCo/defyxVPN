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
  String get ping => '延迟';

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
  String get marketplace => '市场';

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
  String get mbps => '兆比特/秒';

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
  String get gotIt => '知道了';

  @override
  String get learnMore => '了解更多';

  @override
  String get defyxGoal => 'Defyx的目标是确保安全访问公共信息，并提供免费的浏览体验。';

  @override
  String get statusIsChilling => '正在休息。';

  @override
  String get statusIs => '是';

  @override
  String get statusFailed => '失败了。';

  @override
  String get statusHas => '有';

  @override
  String get statusIsReturning => '正在返回';

  @override
  String get statusToStandbyMode => '到待机模式。';

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
  String get statusTestingSpeed => '测试速度中 ...';

  @override
  String get statusIsReady => '已准备好';

  @override
  String get statusIsInTrouble => '遇到麻烦了.';

  @override
  String get statusDXcoreDown => 'DXcore 已关闭.';

  @override
  String get statusToSpeedTest => '进行速度测试';

  @override
  String get statusYoursToShape => '由您塑造';

  @override
  String get settingsConnectionMethod => '连接方式';

  @override
  String get settingsEscapeMode => '逃逸模式';

  @override
  String get settingsDestination => '目的地';

  @override
  String get settingsSplitTunnel => '分离隧道';

  @override
  String get settingsKillSwitch => '终止开关';

  @override
  String get settingsDeepScan => '深度扫描';

  @override
  String get settingsHealthCheck => '健康检查';

  @override
  String get settingsIncluded => '已包含';

  @override
  String get settingsAtLeastOneCoreRequired => '至少需要保留一个核心';

  @override
  String get settingsResetToDefault => '重置';

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
  String get havingTrouble => '遇到问题？';

  @override
  String get signedInAs => '您当前已使用电子邮件地址登录';

  @override
  String get premiumImportDescription =>
      '如果由于互联网限制无法加载您的高级订阅，并且您无法使用可用方法连接，您可以将从市场获得的文件导入应用程序。';

  @override
  String get planningToExit => '打算退出？';

  @override
  String get signOut => '退出';

  @override
  String get signOutSuccess => '退出成功！';

  @override
  String get settingsMarketplace => '市场';

  @override
  String get marketplaceDescription => '浏览来自可信供应商的安全VPN配置。';

  @override
  String get loggedIn => '已登录';

  @override
  String get loginOrRegister => '登录或注册';
}
