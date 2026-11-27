import MacDXcore
import NetworkExtension
import os.log

// Mirrors ios/PacketTunnel/PacketTunnelProvider.swift: the same tunnel
// addresses, the same commands from the app, and the same replies.
class PacketTunnelProvider: NEPacketTunnelProvider {

    private let tunnelAddress = "172.18.0.1"
    private let tunnelMask = "255.255.255.252"
    private let tunnelAddress6 = "fdfe:dcba:9876::1"
    private let tunnelPrefix6: NSNumber = 126
    private let tunnelDns = "172.18.0.2"
    private let tunnelMtu = 1500

    private var appliedSettings: NEPacketTunnelNetworkSettings?

    override init() {
        super.init()
        MacosSetProgressListener(ProgressStreamHandler())
    }

    override func startTunnel(
        options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("Starting sing-box tunnel...")

        let settings = tunnelSettings()

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error = error {
                os_log("Failed to apply tunnel settings: %{public}@", error.localizedDescription)
                completionHandler(error)
                return
            }

            self?.appliedSettings = settings
            os_log("Tunnel settings applied, waiting for the core to be ready")
            completionHandler(nil)
        }
    }

    private func tunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)

        let ipv4 = NEIPv4Settings(addresses: [tunnelAddress], subnetMasks: [tunnelMask])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(
            addresses: [tunnelAddress6], networkPrefixLengths: [tunnelPrefix6])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: [tunnelDns])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        settings.mtu = NSNumber(value: tunnelMtu)

        return settings
    }

    // Re-applying the settings makes the system drop the DNS answers it cached
    // before the core took over.
    private func clearDnsCache(completion: @escaping () -> Void) {
        guard let settings = appliedSettings else {
            completion()
            return
        }

        reasserting = true
        setTunnelNetworkSettings(nil) { [weak self] _ in
            guard let self = self else {
                completion()
                return
            }
            self.setTunnelNetworkSettings(settings) { _ in
                self.reasserting = false
                os_log("System dns cache dropped")
                completion()
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        os_log("VPN stopped with reason: %d", reason.rawValue)
        os_log("Stopping VPN tunnel...")
        MacosStopTunnel()
        _ = MacosStopVPN()
        os_log("Tunnel stopped successfully.")
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let json = try? JSONSerialization.jsonObject(with: messageData, options: []),
            let dict = json as? [String: String],
            let command = dict["command"]
        else {
            os_log("Invalid JSON or missing command.")
            completionHandler?(nil)
            return
        }

        os_log("Received command: %@", command)

        let reply: (String) -> Void = { completionHandler?($0.data(using: .utf8)) }

        switch command {
        case "START_TUNNEL":
            MacosSetSplitTunnel(dict["mode"] ?? "off", dict["rules"] ?? "[]", dict["apps"] ?? "[]")
            // 0 lets the core find the tunnel's file descriptor itself, as on iOS.
            let success = MacosStartTunnel(0)
            let response = success ? "TUNNEL_STARTED" : "TUNNEL_ERROR"
            os_log("Tunnel: %{public}@", response)
            if success {
                clearDnsCache { reply(response) }
            } else {
                reply(response)
            }

        case "MEASURE_PING":
            reply(String(describing: MacosMeasurePing()))

        case "GET_FLAG":
            reply(MacosGetFlag())

        case "START_VPN":
            MacosStartVPN(
                dict["cacheDir"] ?? "",
                dict["flowLine"] ?? "",
                dict["pattern"] ?? "",
                Bool(dict["deepScan"] ?? "false") ?? false,
                Bool(dict["healthCheck"] ?? "false") ?? false)
            reply("VPN started successfully")

        case "STOP_VPN":
            _ = MacosStopVPN()
            reply("VPN_STOPPED")

        case "SET_ASN_NAME":
            MacosSetAsnName()
            reply("ASN_NAME_SET")

        case "SET_TIMEZONE":
            let timezone = Float(dict["timezone"] ?? "0.0") ?? 0
            if MacosSetTimeZone(timezone) {
                os_log("local time zone set successfully")
                reply("LOCAL_TIMEZONE_SET")
            } else {
                os_log("Failed to set local time zone")
                reply("LOCAL_TIMEZONE_ERROR: false")
            }

        case "GET_FLOW_LINE":
            let isTest = Bool(dict["isTest"] ?? "false") ?? false
            reply(MacosGetFlowLine(isTest, dict["token"] ?? ""))

        case "GET_CACHED_FLOW_LINE":
            reply(MacosGetCachedFlowLine())

        case "DECODE_VERIFY_FLOWLINE":
            // The macOS core exports this one with a doubled prefix.
            reply(MacosMacosDecodeAndVerifyFlowline(dict["flowLine"] ?? ""))

        case "SET_CACHE_DIR":
            MacosSetCacheDir(dict["cacheDir"] ?? "")
            reply("true")

        default:
            os_log("⚠️ Unknown command received.")
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("😴 Tunnel going to sleep...")
        completionHandler()
    }

    override func wake() {
        os_log("🔄 Tunnel waking up...")
    }
}

class ProgressStreamHandler: NSObject, MacosProgressListenerProtocol {
    func onProgress(_ msg: String?) {
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            var logs = defaults.stringArray(forKey: "vpn_logs") ?? []
            logs.append(msg ?? "")
            defaults.set(logs, forKey: "vpn_logs")
            defaults.synchronize()
        }
    }
}
