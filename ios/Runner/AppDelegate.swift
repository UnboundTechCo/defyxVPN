import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var vpnPlugin: VpnPlugin?
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    vpnPlugin = VpnPlugin()

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.defyx.vpn",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, result) in
        self?.vpnPlugin?.handleMethodCall(call, result: result)
      }

      let eventChannel = FlutterEventChannel(
        name: "com.defyx.vpn_events",
        binaryMessenger: controller.binaryMessenger)
      eventChannel.setStreamHandler(StatusStreamHandler(plugin: vpnPlugin!))

      let progressChannel = FlutterEventChannel(
        name: "com.defyx.progress_events",
        binaryMessenger: controller.binaryMessenger)
      let progressHandler = ProgressStreamHandler()
      progressChannel.setStreamHandler(progressHandler)

      let screenSecurityChannel = FlutterMethodChannel(
        name: "com.defyx.screen_security",
        binaryMessenger: controller.binaryMessenger)
      screenSecurityChannel.setMethodCallHandler { [weak self] (call, result) in
        self?.handleScreenSecurityMethodCall(call, result: result)
      }

      getLogs(progressHandler)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func handleScreenSecurityMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enableScreenSecurity":
      ScreenSecurity.enableScreenSecurity(for: window)
      result(nil)
    case "disableScreenSecurity":
      ScreenSecurity.disableScreenSecurity(for: window)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
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
}

// ScreenSecurity implementation for iOS
class ScreenSecurity {
  static func enableScreenSecurity(for window: UIWindow?) {
    guard let window = window else { return }
    window.layer.isSecure = true
  }
  
  static func disableScreenSecurity(for window: UIWindow?) {
    guard let window = window else { return }
    window.layer.isSecure = false
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