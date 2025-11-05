import Combine
import FlutterMacOS
import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
class VpnPlugin: VpnStatusDelegate {

    private var flutterResult: FlutterResult?
    private var eventSink: FlutterEventSink?

    init() {
        VpnService.shared.statusDelegate = self
    }

    func setEventSink(_ sink: @escaping FlutterEventSink) {
        self.eventSink = sink

        VpnService.shared.loadManager { success in
            if success, let status = VpnService.shared.manager?.connection.status {
                self.sendVpnStatusToFlutter(status)
            } else {
                self.sendVpnStatusToFlutter(.disconnected)
            }
        }
    }

    private func sendVpnStatusToFlutter(_ status: NEVPNStatus) {
        var statusString = ""

        switch status {
        case .connected: statusString = "connected"
        case .connecting: statusString = "connecting"
        case .disconnected: statusString = "disconnected"
        case .disconnecting: statusString = "disconnecting"
        case .invalid: statusString = "disconnected"  
        case .reasserting: statusString = "connecting"  
        @unknown default: statusString = "disconnected" 
        }

        print("Sending VPN status to Flutter: \(statusString)")
        eventSink?(["status": statusString])
    }

    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.flutterResult = result

        switch call.method {
        case "connect":
            connectVPN(result)
        case "disconnect":
            disconnectVPN(result)
        case "startTun2socks":
            startTun2socks(result)
        case "getVpnStatus":
            getVpnStatus(result)
        case "calculatePing":
            measurePing(result)
        case "getFlag":
            getFlag(result)
        case "startVPN":
            startVPN(call.arguments as? [String: Any], result)
        case "stopVPN":
            stopVPN(result)
        case "setAsnName":
            setAsnName(result)
        case "setTimezone":
            setTimezone(call.arguments as? [String: Any], result)
        case "getFlowLine":
            getFlowLine(call.arguments as? [String: Any], result)
        case "setConnectionMethod":
            print("setConnectionMethod")
        case "isTunnelRunning":
            isTunnelRunning(result)
        case "prepareVPN":
            prepareVPN(result)
        case "isVPNPrepared":
            isVPNPrepared(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connectVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.prepareVPN { prepareResult in
            switch prepareResult {
            case .success:
                DispatchQueue.main.async {
                    VpnService.shared.startVPN(port: 5000) { _ in
                        result(true)
                    }
                }
            case .failure(let error):
                print("❌ VPN Prepare failed: \(error)")
                result(false)
            }
        }
    }

    private func prepareVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.prepareVPN { prepareResult in
            switch prepareResult {
            case .success:
                result(true)
            case .failure(let error):
                print("❌ VPN Prepare failed: \(error)")
                result(false)
            }
        }
    }

    private func disconnectVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.stopVPN { _ in
            result(true)
        }
    }

    private func getVpnStatus(_ result: @escaping FlutterResult) {
        if VpnService.shared.manager == nil {
            VpnService.shared.loadManager { success in
                if success {
                    self.returnCurrentVpnStatus(result)
                } else {
                    result("disconnected")
                }
            }
        } else {
            returnCurrentVpnStatus(result)
        }
    }

    private func returnCurrentVpnStatus(_ result: @escaping FlutterResult) {
        if let status = VpnService.shared.manager?.connection.status {
            var statusString = ""

            switch status {
            case .connected: statusString = "connected"
            case .connecting: statusString = "connecting"
            case .disconnected: statusString = "disconnected"
            case .disconnecting: statusString = "disconnecting"
            case .invalid: statusString = "disconnected"  
            case .reasserting: statusString = "connecting"  
            @unknown default: statusString = "disconnected"  
            }
            print("VPN STATUS IS: \(statusString)")
            result(statusString)
        } else {
            result("disconnected")
        }
    }

    func vpnStatusDidChange(_ status: NEVPNStatus) {
        print("VPN status changed to: \(status)")
        sendVpnStatusToFlutter(status)
    }

    private func startTun2socks(_ result: @escaping FlutterResult) {
        VpnService.shared.sendTunnelMessage(["command": "START_TUN2SOCKS"]) { response in
            if response == "TUN2SOCKS_STARTED" {
                result(true)
            } else {
                result(false)
            }
        }
    }

    private func getSharedDirectory() -> String {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.de.unboundtech.defyxvpn")
        {
            return groupURL.path
        }
        return "/dev/null"
    }

    private func measurePing(_ result: @escaping FlutterResult) {
        VpnService.shared.sendTunnelMessage(["command": "MEASURE_PING"]) { response in
            result(response)
        }
    }
    private func startVPN(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        let primaryPath = URL(fileURLWithPath: getSharedDirectory()).appendingPathComponent(
            "primary")
        do {
            try FileManager.default.createDirectory(
                at: primaryPath, withIntermediateDirectories: true)
        } catch {
            os_log("❌ Failed to create primary directory: %@", error.localizedDescription)
            result(
                FlutterError(
                    code: "DIRECTORY_ERROR", message: "Failed to create directory",
                    details: error.localizedDescription))
            return
        }
        let dir = URL(fileURLWithPath: getSharedDirectory())
        guard let args = arguments,
            let flowLine = args["flowLine"] as? String,
            let pattern = args["pattern"] as? String
        else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS", message: "Missing required parameters", details: nil)
            )
            return
        }
        VpnService.shared.sendTunnelMessage([
            "command": "START_VPN", "cacheDir": dir.path, "flowLine": flowLine, "pattern": pattern,
        ]) {
            response in
            result(response)
        }
    }
    private func stopVPN(_ result: @escaping FlutterResult) {
        VpnService.shared.sendTunnelMessage(["command": "STOP_VPN"]) { response in
            result(response)
        }
        disconnectVPN(result)
    }
    private func getFlag(_ result: @escaping FlutterResult) {
        VpnService.shared.sendTunnelMessage(["command": "GET_FLAG"]) { response in
            result(response)
        }
    }
    private func setAsnName(_ result: @escaping FlutterResult) {
        VpnService.shared.sendTunnelMessage(["command": "SET_ASN_NAME"]) { response in
            result(response)
        }
    }
    private func setTimezone(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let args = arguments,
            let timezone = args["timezone"] as? String
        else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS", message: "Missing required parameters", details: nil)
            )
            return
        }

        VpnService.shared.sendTunnelMessage([
            "command": "SET_TIMEZONE",
            "timezone": timezone,
        ]) { response in
            result(response)
        }
    }

    private func getFlowLine(_ arguments: [String: Any]?, _ result: @escaping FlutterResult) {
        guard let args = arguments,
            let isTest = args["isTest"] as? String
        else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS", message: "Missing required parameters", details: nil)
            )
            return
        }

        VpnService.shared.sendTunnelMessage(["command": "GET_FLOW_LINE", "isTest": isTest]) {
            response in
            result(response)
        }
    }
    private func isTunnelRunning(_ result: @escaping FlutterResult) {
        if VpnService.shared.manager == nil {
            result(false)
        } else {
            if let status = VpnService.shared.manager?.connection.status {
                var statusBool = false

                switch status {
                case .connected: statusBool = true
                case .connecting: statusBool = true
                case .disconnected: statusBool = false
                case .disconnecting: statusBool = true
                case .invalid: statusBool = false  
                case .reasserting: statusBool = true
                @unknown default: statusBool = false 
                }
                result(statusBool)
            } else {
                result(false)
            }
        }
    }

    private func isVPNPrepared(_ result: @escaping FlutterResult) {
        if VpnService.shared.manager == nil {
            result(false)
        } else {
            result(true)
        }
    }

}