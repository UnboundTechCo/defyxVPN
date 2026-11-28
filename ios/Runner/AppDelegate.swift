import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate,FlutterImplicitEngineDelegate {
  private var vpnPlugin: VpnPlugin?
  private var vibrationPlugin: VibrationPlugin?
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: DefyxNativeAdFactory.factoryId,
      nativeAdFactory: DefyxNativeAdFactory()
    )

    let messenger = engineBridge.applicationRegistrar.messenger()
    let vpnPlugin = VpnPlugin()
    let vibrationPlugin = VibrationPlugin()

    self.vpnPlugin = vpnPlugin
    self.vibrationPlugin = vibrationPlugin

    let vpnChannel = FlutterMethodChannel(
      name: "com.defyx.vpn",
      binaryMessenger: messenger
    )
    vpnChannel.setMethodCallHandler { [weak self] call, result in
      self?.vpnPlugin?.handleMethodCall(call, result: result)
    }

    let vibrationChannel = FlutterMethodChannel(
      name: "com.defyx.vibration",
      binaryMessenger: messenger
    )
    vibrationChannel.setMethodCallHandler { [weak self] call, result in
      self?.vibrationPlugin?.handleMethodCall(call, result: result)
    }

    let statusChannel = FlutterEventChannel(
      name: "com.defyx.vpn_events",
      binaryMessenger: messenger
    )
    statusChannel.setStreamHandler(StatusStreamHandler(plugin: vpnPlugin))

    let progressChannel = FlutterEventChannel(
      name: "com.defyx.progress_events",
      binaryMessenger: messenger
    )
    let progressHandler = ProgressStreamHandler()
    progressChannel.setStreamHandler(progressHandler)

    let crashChannel = FlutterEventChannel(
      name: "com.defyx.crash_events",
      binaryMessenger: messenger
    )
    let crashHandler = CrashStreamHandler()
    crashChannel.setStreamHandler(crashHandler)

    getLogs(progressHandler)
    getCrashes(crashHandler)
  }

  func getLogs(_ progressHandler: ProgressStreamHandler) {
    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      guard let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn"),
        var logs = defaults.stringArray(forKey: "vpn_logs"),
        !logs.isEmpty
      else { return }

      let logsToSend = logs

      for log in logsToSend {
        progressHandler.send(log)
      }

      var currentLogs = defaults.stringArray(forKey: "vpn_logs") ?? []

      if currentLogs.count >= logsToSend.count {
        currentLogs.removeFirst(logsToSend.count)
      } else {
        currentLogs.removeAll()
      }

      defaults.set(currentLogs, forKey: "vpn_logs")
      defaults.synchronize()
    }
  }

  func getCrashes(_ crashHandler: CrashStreamHandler) {
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
      guard let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn"),
        var crashes = defaults.array(forKey: "go_crashes") as? [[String: String]],
        !crashes.isEmpty
      else { return }

      let crashesToSend = crashes

      for crash in crashesToSend {
        crashHandler.send(crash)
      }

      var currentCrashes = defaults.array(forKey: "go_crashes") as? [[String: String]] ?? []

      if currentCrashes.count >= crashesToSend.count {
        currentCrashes.removeFirst(crashesToSend.count)
      } else {
        currentCrashes.removeAll()
      }

      defaults.set(currentCrashes, forKey: "go_crashes")
      defaults.synchronize()
    }
  }
}

class ProgressStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  func send(_ log: String) {
    eventSink?(log)
  }
}

class StatusStreamHandler: NSObject, FlutterStreamHandler {
  private let plugin: VpnPlugin

  init(plugin: VpnPlugin) {
    self.plugin = plugin
    super.init()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    plugin.setEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    plugin.setEventSink({ _ in })
    return nil
  }
}

class CrashStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  func send(_ crashInfo: [String: String]) {
    eventSink?(crashInfo)
  }
}

/// AdMob native card for the main screen's ad box (Dart factoryId
/// "defyxNative"; the Android twin is DefyxNativeAdFactory.kt).
///
/// Google's medium template does not fit the box: its 16:9 media plus the
/// header row and the button need more height than the box has, so the
/// button was cut off. This card fills whatever size it is given; see
/// DefyxNativeAdView.
final class DefyxNativeAdFactory: NSObject, FLTNativeAdFactory {
  static let factoryId = "defyxNative"

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = DefyxNativeAdView(frame: .zero)
    adView.bind(nativeAd)
    return adView
  }
}

/// Tall enough, the media sits on top with the icon and headline row and
/// the button below it. In a shorter box that would squeeze the media under
/// AdMob's 120x120pt minimum, so there the media is a square on the left
/// with the headline, attribution and button beside it.
final class DefyxNativeAdView: NativeAdView {
  private static let background = UIColor(
    red: 0x19 / 255.0, green: 0x31 / 255.0, blue: 0x2F / 255.0, alpha: 1)
  private static let brandYellow = UIColor(
    red: 0xFF / 255.0, green: 0xC9 / 255.0, blue: 0x27 / 255.0, alpha: 1)

  private static let inset: CGFloat = 5
  // The vertical arrangement keeps the media at 120pt from this height on:
  // 120 + 6 + 40 (icon row) + 6 + 40 (button) + 2 x 5.
  private static let verticalMinHeight: CGFloat = 222

  private let media = MediaView()
  private let icon = UIImageView()
  private let headline = UILabel()
  private let badge = UILabel()
  private let secondary = UILabel()
  private let cta = UIButton(type: .custom)

  private var verticalConstraints: [NSLayoutConstraint] = []
  private var compactConstraints: [NSLayoutConstraint] = []
  private var mediaWidth: NSLayoutConstraint!
  private var mediaHeight: NSLayoutConstraint!
  private var isCompact: Bool?

  override init(frame: CGRect) {
    super.init(frame: frame)
    build()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    build()
  }

  private func build() {
    backgroundColor = Self.background

    media.contentMode = .scaleAspectFit

    icon.contentMode = .scaleAspectFit
    icon.layer.cornerRadius = 6
    icon.clipsToBounds = true

    headline.font = .boldSystemFont(ofSize: 15)
    headline.textColor = .white
    headline.lineBreakMode = .byTruncatingTail

    // Ad attribution, required on native ads.
    badge.text = "Ad"
    badge.font = .boldSystemFont(ofSize: 10)
    badge.textColor = Self.background
    badge.backgroundColor = Self.brandYellow
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.clipsToBounds = true

    secondary.font = .systemFont(ofSize: 12)
    secondary.textColor = UIColor.white.withAlphaComponent(0.7)
    secondary.lineBreakMode = .byTruncatingTail

    cta.setTitleColor(Self.background, for: .normal)
    cta.titleLabel?.font = .boldSystemFont(ofSize: 16)
    cta.titleLabel?.lineBreakMode = .byTruncatingTail
    cta.backgroundColor = Self.brandYellow
    cta.layer.cornerRadius = 8
    // The ad view handles the tap; the button must not swallow it.
    cta.isUserInteractionEnabled = false

    for view in [media, icon, headline, badge, secondary, cta] as [UIView] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
  }

  func bind(_ nativeAd: NativeAd) {
    media.mediaContent = nativeAd.mediaContent
    icon.image = nativeAd.icon?.image
    headline.text = nativeAd.headline
    if let advertiser = nativeAd.advertiser, !advertiser.isEmpty {
      secondary.text = advertiser
      advertiserView = secondary
    } else if let store = nativeAd.store, !store.isEmpty {
      secondary.text = store
      storeView = secondary
    }
    cta.setTitle(nativeAd.callToAction, for: .normal)
    cta.isHidden = nativeAd.callToAction == nil

    makeConstraints(hasIcon: nativeAd.icon != nil)

    mediaView = media
    iconView = icon
    headlineView = headline
    callToActionView = cta
    self.nativeAd = nativeAd
  }

  private func makeConstraints(hasIcon: Bool) {
    let inset = Self.inset
    let iconSize: CGFloat = hasIcon ? 40 : 0

    // In both arrangements.
    NSLayoutConstraint.activate([
      headline.trailingAnchor.constraint(
        equalTo: trailingAnchor, constant: -inset),

      badge.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
      badge.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
      badge.widthAnchor.constraint(equalToConstant: 22),
      badge.heightAnchor.constraint(equalToConstant: 16),

      secondary.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
      secondary.leadingAnchor.constraint(
        equalTo: badge.trailingAnchor, constant: 6),
      secondary.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor, constant: -inset),

      cta.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
      cta.heightAnchor.constraint(equalToConstant: 40),
      cta.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
    ])

    // Media on top, then the icon and headline row, then the button.
    verticalConstraints = [
      media.topAnchor.constraint(equalTo: topAnchor, constant: inset),
      media.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
      media.trailingAnchor.constraint(
        equalTo: trailingAnchor, constant: -inset),

      icon.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 6),
      icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
      icon.widthAnchor.constraint(equalToConstant: iconSize),
      icon.heightAnchor.constraint(equalToConstant: 40),

      headline.topAnchor.constraint(equalTo: icon.topAnchor),
      headline.leadingAnchor.constraint(
        equalTo: icon.trailingAnchor, constant: hasIcon ? 8 : 0),

      cta.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
      cta.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
    ]

    // The media as a square on the left, as large as the height allows (at
    // most half the width; set in layoutSubviews); beside it the headline
    // (two lines), the attribution and the button. No room for the icon.
    mediaWidth = media.widthAnchor.constraint(equalToConstant: 0)
    mediaHeight = media.heightAnchor.constraint(equalToConstant: 0)
    compactConstraints = [
      media.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
      media.centerYAnchor.constraint(equalTo: centerYAnchor),
      mediaWidth,
      mediaHeight,

      icon.topAnchor.constraint(equalTo: media.topAnchor),
      icon.leadingAnchor.constraint(equalTo: media.trailingAnchor),
      icon.widthAnchor.constraint(equalToConstant: 0),
      icon.heightAnchor.constraint(equalToConstant: 0),

      headline.topAnchor.constraint(equalTo: topAnchor, constant: inset),
      headline.leadingAnchor.constraint(
        equalTo: media.trailingAnchor, constant: 10),

      cta.leadingAnchor.constraint(
        equalTo: media.trailingAnchor, constant: 10),
    ]
  }

  override func layoutSubviews() {
    // Not bound to an ad yet.
    guard !verticalConstraints.isEmpty else {
      super.layoutSubviews()
      return
    }
    let compact = bounds.height < Self.verticalMinHeight
    if compact {
      let side = max(
        0,
        min(
          bounds.height - 2 * Self.inset,
          (bounds.width - 2 * Self.inset) / 2))
      mediaWidth?.constant = side
      mediaHeight?.constant = side
    }
    if compact != isCompact {
      isCompact = compact
      NSLayoutConstraint.deactivate(compact ? verticalConstraints : compactConstraints)
      NSLayoutConstraint.activate(compact ? compactConstraints : verticalConstraints)
      headline.numberOfLines = compact ? 2 : 1
      icon.isHidden = compact
    }
    super.layoutSubviews()
  }
}
