import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var vpnPlugin: VpnPlugin?
  private var eventSink: FlutterEventSink?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    vpnPlugin = VpnPlugin()

    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    let channel = FlutterMethodChannel(
      name: "com.defyx.vpn",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.vpnPlugin?.handleMethodCall(call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: "com.defyx.vpn_events",
      binaryMessenger: controller.engine.binaryMessenger)
    eventChannel.setStreamHandler(StatusStreamHandler(plugin: vpnPlugin!))

    let progressChannel = FlutterEventChannel(
      name: "com.defyx.progress_events",
      binaryMessenger: controller.engine.binaryMessenger)
    let progressHandler = ProgressStreamHandler()
    progressChannel.setStreamHandler(progressHandler)

    getLogs(progressHandler)
  }

  func getLogs(_ progressHandler: ProgressStreamHandler) {
    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      guard let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn"),
        let logs = defaults.stringArray(forKey: "vpn_logs"),
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