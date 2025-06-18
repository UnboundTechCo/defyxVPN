import Flutter

public class WarpPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.defyx.warp_plus", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.defyx.warp_plus_events", binaryMessenger: registrar.messenger())
        let instance = WarpPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            result(true)
        case "disconnect":
            result(true)
        case "startWarp":
            result(true)
        case "stopWarp":
            result(true)
        case "startTun2socks":
            result(true)
        case "getVpnStatus":
            result("disconnected")
        case "getLogs":
            result("[INFO] Dummy VPN running normally")
        case "calculatePing":
            let randomPing = Int.random(in: 50...150)
            result(randomPing)
        case "getFlag":
            let flags = ["us", "gb", "de", "jp", "sg"]
            let randomFlag = flags.randomElement() ?? "us"
            result(randomFlag)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension WarpPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // No events in dummy implementation
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
