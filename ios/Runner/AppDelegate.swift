import Flutter
import UIKit

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
