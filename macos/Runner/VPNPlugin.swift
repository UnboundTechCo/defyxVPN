import Combine
import FlutterMacOS
import Foundation
import MacDXcore
import NetworkExtension
import os.log

// Mirrors ios/Runner/VPNPlugin.swift. The app runs its own copy of the core for
// everything that does not need the tunnel (flowline, ping, flag, login), and
// asks the packet tunnel extension to start and stop the VPN itself.
@available(macOS 11.0, *)
class VpnPlugin: VpnStatusDelegate {

    private var eventSink: FlutterEventSink?
    private let goQueue = DispatchQueue(label: "go.runtime.queue", qos: .userInitiated)

    init() {
        VpnService.shared.statusDelegate = self
        MacosSetProgressListener(ProgressStreamHandlerMacOS())
        // The macOS core has no SetCrashCallback yet, so Go panics in the app
        // are not forwarded to Flutter the way they are on iOS.
    }

    // MARK: - Event Sink
    func setEventSink(_ sink: @escaping FlutterEventSink) {
        self.eventSink = sink

        // Load the manager first so Flutter starts from the real connection state.
        VpnService.shared.loadManager { success in
            let status = success ? VpnService.shared.manager?.connection.status : nil
            self.sendVpnStatusToFlutter(status ?? .disconnected)
        }
    }

    private func sendVpnStatusToFlutter(_ status: NEVPNStatus) {
        let statusString = Self.statusString(status)
        print("Sending VPN status to Flutter: \(statusString)")
        DispatchQueue.main.async { self.eventSink?(["status": statusString]) }
    }

    private static func statusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "connected"
        case .connecting, .reasserting: return "connecting"
        case .disconnecting: return "disconnecting"
        case .disconnected, .invalid: return "disconnected"
        @unknown default: return "disconnected"
        }
    }

    // MARK: - Flutter Method Call Handler
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Flutter must be answered on the main thread, whichever thread the
        // work finishes on.
        let reply: FlutterResult = { value in
            if Thread.isMainThread {
                result(value)
            } else {
                DispatchQueue.main.async { result(value) }
            }
        }
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "connect":
            connectVPN(reply)
        case "disconnect":
            disconnectVPN(reply)
        case "getVpnStatus":
            getVpnStatus(reply)
        case "calculatePing":
            measurePing(reply)
        case "getFlag":
            getFlag(reply)
        case "startVPN":
            startVPN(args, reply)
        case "stopVPN":
            stopVPN(reply)
        case "setAsnName":
            setAsnName(reply)
        case "setTimezone":
            setTimezone(args, reply)
        case "getFlowLine":
            getFlowLine(args, reply)
        case "getCachedFlowLine":
            getCachedFlowLine(reply)
        case "decodeAndVerifyFlowline":
            decodeAndVerifyFlowline(args, reply)
        case "setCacheDir":
            setCacheDir(args, reply)
        case "getSharedDirectory":
            reply("\(getSharedDirectory())/defyx")
        case "setConnectionMethod":
            reply(nil)
        case "startTunnel":
            startTunnel(args, reply)
        case "isTunnelRunning":
            isTunnelRunning(reply)
        case "prepareVPN":
            prepareVPN(reply)
        case "isVPNPrepared":
            isVPNPrepared(reply)
        case "login":
            login(args, reply)
        case "loginByCode":
            loginByCode(args, reply)
        default:
            reply(FlutterMethodNotImplemented)
        }
    }

    private func invalidArguments(_ result: FlutterResult) {
        result(
            FlutterError(
                code: "INVALID_ARGUMENTS", message: "Missing required parameters", details: nil))
    }

    // MARK: - VPN Management
    // Creates the VPN profile if needed, which asks the user once, then starts
    // the packet tunnel. The core itself is started later with startVPN.
    private func connectVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.prepareVPN { prepareResult in
            switch prepareResult {
            case .success:
                DispatchQueue.main.async {
                    VpnService.shared.startVPN(port: 5000) { startResult in
                        if case .failure(let error) = startResult {
                            print("❌ VPN start failed: \(error)")
                            result(false)
                        } else {
                            result(true)
                        }
                    }
                }
            case .failure(let error):
                print("❌ VPN Prepare failed: \(error)")
                result(false)
            }
        }
    }

    private func disconnectVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.stopVPN { _ in result(true) }
    }

    private func prepareVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.prepareVPN { prepareResult in
            if case .failure(let error) = prepareResult {
                print("❌ VPN Prepare failed: \(error)")
                result(false)
            } else {
                result(true)
            }
        }
    }

    private func isVPNPrepared(_ result: @escaping FlutterResult) {
        VpnService.shared.isVPNPrepared { prepareResult in
            if case .failure(let error) = prepareResult {
                print("❌ VPN is not Prepared: \(error)")
                result(false)
            } else {
                result(true)
            }
        }
    }

    // MARK: - VPN Status
    private func getVpnStatus(_ result: @escaping FlutterResult) {
        if VpnService.shared.manager == nil {
            VpnService.shared.loadManager { _ in self.returnCurrentVpnStatus(result) }
        } else {
            returnCurrentVpnStatus(result)
        }
    }

    private func returnCurrentVpnStatus(_ result: @escaping FlutterResult) {
        guard let status = VpnService.shared.manager?.connection.status else {
            result("disconnected")
            return
        }
        let statusString = Self.statusString(status)
        print("VPN STATUS IS: \(statusString)")
        result(statusString)
    }

    private func isTunnelRunning(_ result: @escaping FlutterResult) {
        guard let status = VpnService.shared.manager?.connection.status else {
            result(false)
            return
        }
        switch status {
        case .connected, .connecting, .disconnecting, .reasserting:
            result(true)
        case .disconnected, .invalid:
            result(false)
        @unknown default:
            result(false)
        }
    }

    // MARK: - VPN Status Delegate
    func vpnStatusDidChange(_ status: NEVPNStatus) {
        print("VPN status changed to: \(status)")
        sendVpnStatusToFlutter(status)
    }

    // MARK: - Tunnel commands
    private func startVPN(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        let defyxDir = URL(fileURLWithPath: getSharedDirectory()).appendingPathComponent("defyx")
        do {
            try FileManager.default.createDirectory(
                at: defyxDir.appendingPathComponent("primary"), withIntermediateDirectories: true)
        } catch {
            os_log("❌ Failed to create primary directory: %@", error.localizedDescription)
            result(
                FlutterError(
                    code: "DIRECTORY_ERROR", message: "Failed to create directory",
                    details: error.localizedDescription))
            return
        }
        guard let args = arguments,
            let flowLine = args["flowLine"] as? String,
            let pattern = args["pattern"] as? String,
            let deepScan = args["deepScan"] as? String,
            let healthCheck = args["healthCheck"] as? String
        else {
            invalidArguments(result)
            return
        }
        VpnService.shared.sendTunnelMessage([
            "command": "START_VPN",
            "cacheDir": defyxDir.path,
            "flowLine": flowLine,
            "pattern": pattern,
            "deepScan": deepScan,
            "healthCheck": healthCheck,
        ]) { response in
            result(response)
        }
    }

    // The core stops before the tunnel goes down, and Flutter gets a single
    // reply once both are done. A tunnel that does not answer within a few
    // seconds is taken down anyway.
    private func stopVPN(_ result: @escaping FlutterResult) {
        var disconnecting = false
        let disconnect = {
            DispatchQueue.main.async {
                if disconnecting { return }
                disconnecting = true
                self.disconnectVPN(result)
            }
        }
        VpnService.shared.sendTunnelMessage(["command": "STOP_VPN"]) { _ in disconnect() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { disconnect() }
    }

    private func startTunnel(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        let message = [
            "command": "START_TUNNEL",
            "mode": arguments?["mode"] as? String ?? "off",
            "rules": arguments?["rules"] as? String ?? "[]",
            "apps": arguments?["apps"] as? String ?? "[]",
        ]
        VpnService.shared.sendTunnelMessage(message) { response in
            result(response == "TUNNEL_STARTED")
        }
    }

    // MARK: - Core calls in the app process
    private func measurePing(_ result: @escaping FlutterResult) {
        goQueue.async { result(MacosMeasurePing()) }
    }

    private func getFlag(_ result: @escaping FlutterResult) {
        goQueue.async { result(MacosGetFlag()) }
    }

    private func setAsnName(_ result: @escaping FlutterResult) {
        goQueue.async {
            MacosSetAsnName()
            result("flowline")
        }
    }

    private func setTimezone(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let timezone = arguments?["timezone"] as? String else {
            invalidArguments(result)
            return
        }
        let timezoneFloat = Float(timezone) ?? 0
        goQueue.async { result(MacosSetTimeZone(timezoneFloat)) }
    }

    private func getFlowLine(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let args = arguments,
            let isTest = args["isTest"] as? String,
            let token = args["token"] as? String
        else {
            invalidArguments(result)
            return
        }
        let isTestBool = Bool(isTest) ?? false
        goQueue.async { result(MacosGetFlowLine(isTestBool, token)) }
    }

    private func getCachedFlowLine(_ result: @escaping FlutterResult) {
        goQueue.async { result(MacosGetCachedFlowLine()) }
    }

    private func decodeAndVerifyFlowline(
        _ arguments: [String: Any]?, _ result: @escaping FlutterResult
    ) {
        guard let flowLine = arguments?["flowLine"] as? String else {
            invalidArguments(result)
            return
        }
        // The macOS core exports this one with a doubled prefix.
        goQueue.async { result(MacosMacosDecodeAndVerifyFlowline(flowLine)) }
    }

    private func setCacheDir(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let cacheDir = arguments?["cacheDir"] as? String else {
            invalidArguments(result)
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: cacheDir), withIntermediateDirectories: true)
            os_log("Created cache directory")
        } catch {
            os_log("Failed to create cache directory: %@", error.localizedDescription)
        }
        goQueue.async {
            MacosSetCacheDir(cacheDir)
            result(nil)
        }
    }

    private func login(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let args = arguments,
            let email = args["email"] as? String,
            let password = args["password"] as? String
        else {
            invalidArguments(result)
            return
        }
        goQueue.async { result(MacosLogin(email, password)) }
    }

    private func loginByCode(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let code = arguments?["code"] as? String else {
            invalidArguments(result)
            return
        }
        goQueue.async { result(MacosLoginByCode(code)) }
    }

    private func getSharedDirectory() -> String {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.path
            ?? "/dev/null"
    }
}

private let appGroup = "group.de.unboundtech.defyxvpn"

// The core reports progress from the app process here. Messages go through the
// app group's defaults, where AppDelegate picks them up together with the ones
// the tunnel extension writes.
class ProgressStreamHandlerMacOS: NSObject, MacosProgressListenerProtocol {
    func onProgress(_ msg: String?) {
        if let defaults = UserDefaults(suiteName: appGroup) {
            var logs = defaults.stringArray(forKey: "vpn_logs") ?? []
            logs.append(msg ?? "")
            defaults.set(logs, forKey: "vpn_logs")
            defaults.synchronize()
        }
    }
}
