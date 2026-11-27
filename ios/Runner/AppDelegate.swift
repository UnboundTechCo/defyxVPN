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
/// "defyxNative").
///
/// Google's medium template does not fit the box: its 16:9 media plus the
/// header row and the button need more height than the box has, so the
/// button was cut off. This layout fills whatever height it is given; the
/// media takes what the header row and the button leave.
final class DefyxNativeAdFactory: NSObject, FLTNativeAdFactory {
  static let factoryId = "defyxNative"

  private static let background = UIColor(
    red: 0x19 / 255.0, green: 0x31 / 255.0, blue: 0x2F / 255.0, alpha: 1)
  private static let brandYellow = UIColor(
    red: 0xFF / 255.0, green: 0xC9 / 255.0, blue: 0x27 / 255.0, alpha: 1)

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = Self.background

    let media = MediaView()
    media.contentMode = .scaleAspectFit
    media.mediaContent = nativeAd.mediaContent

    let icon = UIImageView(image: nativeAd.icon?.image)
    icon.contentMode = .scaleAspectFit
    icon.layer.cornerRadius = 6
    icon.clipsToBounds = true

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.font = .boldSystemFont(ofSize: 15)
    headline.textColor = .white
    headline.lineBreakMode = .byTruncatingTail

    // Ad attribution, required on native ads.
    let badge = UILabel()
    badge.text = "Ad"
    badge.font = .boldSystemFont(ofSize: 10)
    badge.textColor = Self.background
    badge.backgroundColor = Self.brandYellow
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.clipsToBounds = true

    let secondary = UILabel()
    secondary.font = .systemFont(ofSize: 12)
    secondary.textColor = UIColor.white.withAlphaComponent(0.7)
    secondary.lineBreakMode = .byTruncatingTail
    if let advertiser = nativeAd.advertiser, !advertiser.isEmpty {
      secondary.text = advertiser
      adView.advertiserView = secondary
    } else if let store = nativeAd.store, !store.isEmpty {
      secondary.text = store
      adView.storeView = secondary
    }

    let cta = UIButton(type: .custom)
    cta.setTitle(nativeAd.callToAction, for: .normal)
    cta.setTitleColor(Self.background, for: .normal)
    cta.titleLabel?.font = .boldSystemFont(ofSize: 16)
    cta.backgroundColor = Self.brandYellow
    cta.layer.cornerRadius = 8
    cta.isHidden = nativeAd.callToAction == nil
    // The ad view handles the tap; the button must not swallow it.
    cta.isUserInteractionEnabled = false

    for view in [media, icon, headline, badge, secondary, cta] as [UIView] {
      view.translatesAutoresizingMaskIntoConstraints = false
      adView.addSubview(view)
    }

    let inset: CGFloat = 5
    let iconSize: CGFloat = nativeAd.icon == nil ? 0 : 40
    NSLayoutConstraint.activate([
      media.topAnchor.constraint(equalTo: adView.topAnchor, constant: inset),
      media.leadingAnchor.constraint(
        equalTo: adView.leadingAnchor, constant: inset),
      media.trailingAnchor.constraint(
        equalTo: adView.trailingAnchor, constant: -inset),

      icon.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 6),
      icon.leadingAnchor.constraint(
        equalTo: adView.leadingAnchor, constant: inset),
      icon.widthAnchor.constraint(equalToConstant: iconSize),
      icon.heightAnchor.constraint(equalToConstant: 40),

      headline.topAnchor.constraint(equalTo: icon.topAnchor),
      headline.leadingAnchor.constraint(
        equalTo: icon.trailingAnchor, constant: iconSize == 0 ? 0 : 8),
      headline.trailingAnchor.constraint(
        equalTo: adView.trailingAnchor, constant: -inset),

      badge.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
      badge.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
      badge.widthAnchor.constraint(equalToConstant: 22),
      badge.heightAnchor.constraint(equalToConstant: 16),

      secondary.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
      secondary.leadingAnchor.constraint(
        equalTo: badge.trailingAnchor, constant: 6),
      secondary.trailingAnchor.constraint(
        lessThanOrEqualTo: adView.trailingAnchor, constant: -inset),

      cta.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
      cta.leadingAnchor.constraint(
        equalTo: adView.leadingAnchor, constant: inset),
      cta.trailingAnchor.constraint(
        equalTo: adView.trailingAnchor, constant: -inset),
      cta.heightAnchor.constraint(equalToConstant: 40),
      cta.bottomAnchor.constraint(
        equalTo: adView.bottomAnchor, constant: -inset),
    ])

    adView.mediaView = media
    adView.iconView = icon
    adView.headlineView = headline
    adView.callToActionView = cta
    adView.nativeAd = nativeAd
    return adView
  }
}
