import MacDXcore
import NetworkExtension
import Tun2SocksKit
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var logTimer: Timer?

    override init() {
        super.init()
        let progressStream = ProgressStreamHandler()
        MacosSetProgressListener(progressStream)
    }

    override func startTunnel(
        options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
    ) {
        // Default values
        var port: Int32 = 5000
        var address = "127.0.0.1"
        var mtu = 1280

        // Read from provider configuration
        if let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration,
            let configData = providerConfig["config"] as? Data,
            let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any]
        {
            port = Int32(config["port"] as? Int ?? Int(port))
            address = config["address"] as? String ?? address
            mtu = config["mtu"] as? Int ?? mtu
        }

        // Override with options if provided
        if let optPort = (options?["port"] as? NSNumber)?.int32Value { port = optPort }
        if let optAddress = options?["address"] as? String { address = optAddress }
        if let optMtu = (options?["mtu"] as? NSNumber)?.intValue { mtu = optMtu }

        // Network settings
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.10")
        networkSettings.mtu = NSNumber(value: mtu)

        networkSettings.ipv4Settings = NEIPv4Settings(
            addresses: ["240.0.0.2"],
            subnetMasks: ["255.255.255.0"]
        )
        networkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]

        networkSettings.ipv6Settings = NEIPv6Settings(
            addresses: ["FC00::0001"],
            networkPrefixLengths: [64]
        )
        networkSettings.ipv6Settings?.includedRoutes = [NEIPv6Route.default()]

        networkSettings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        os_log("Applying Tunnel Network Settings...")

        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                os_log("❌ Failed to set network settings: %@", error.localizedDescription)
                completionHandler(error)
                return
            }
            os_log("✅ Network settings applied successfully.")
            completionHandler(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        os_log("⏹ VPN stopped with reason: %d", reason.rawValue)
        os_log("⏹ Stopping VPN tunnel...")
        Socks5Tunnel.quit()
        MacosStop()
        os_log("✅ Tunnel stopped successfully.")
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let json = try? JSONSerialization.jsonObject(with: messageData, options: []),
            let dict = json as? [String: String],
            let command = dict["command"]
        else {
            os_log("❌ Invalid JSON or missing command.")
            completionHandler?(nil)
            return
        }

        os_log("📩 Received command: %@", command)

        switch command {
        case "START_TUN2SOCKS":
            startTun2socks { result in
                let response = result ? "TUN2SOCKS_STARTED" : "TUN2SOCKS_ERROR"
                os_log("✅ Tun2Socks: \(result)")
                completionHandler?(response.data(using: .utf8))
            }

        case "MEASURE_PING":
            do {
                let ping = MacosMeasurePing()
                let response = String(describing: ping)
                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "GET_FLAG":
            do {
                let flag = MacosGetFlag()
                let response: String = flag

                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "START_VPN":
            do {
                let cacheDir = dict["cacheDir"] ?? ""
                let flowLine = dict["flowLine"] ?? ""
                let pattern = dict["pattern"] ?? ""

                MacosStartVPN(cacheDir, flowLine, pattern)

                let response = "VPN started successfully"

                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"
                        ])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "STOP_VPN":
            do {
                MacosStopVPN()
                let response = "VPN_STOPPED"
                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"
                        ])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "SET_ASN_NAME":
            do {
                MacosSetAsnName()
                let response = "ASN_NAME_SET"
                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"
                        ])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "SET_TIMEZONE":
            do {
                let timezone = dict["timezone"] ?? "0.0"
                let timezoneFloat = Float(timezone) ?? 0
                let success = MacosSetTimeZone(timezoneFloat)

                let response: String
                if success {
                    os_log("✅ local time zone set successfully")
                    response = "LOCAL_TIMEZONE_SET"
                } else {
                    os_log(
                        "❌ Failed to set local time zone: %{public}@", String(describing: success))
                    response = "LOCAL_TIMEZONE_ERROR: \(success)"
                }

                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"
                        ])
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "GET_FLOW_LINE":
            do {
                let isTime = dict["isTime"] ?? "false"
                let isTimeBool = Bool(isTime) ?? false
                let flowLine = MacosGetFlowLine(isTimeBool)
                let response: String = flowLine

                if let data = response.data(using: .utf8) {
                    completionHandler?(data)
                } else {
                    throw NSError(
                        domain: "EncodingError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"]
                    )
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

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

    func getLogFilePath() -> String {
        guard
            let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.de.unboundtech.defyxvpn")
        else {
            os_log("Error getting file path..")
            return "/dev/null"
        }
        let path = groupURL.appendingPathComponent("warp_logs.txt").path
        os_log("FilePath received %@", path)
        return path
    }

    private func saveLogToFile(_ logData: Data) {
        let fileName = "warp_logs.txt"
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logData)
                fileHandle.closeFile()
            } else {
                try logData.write(to: fileURL, options: .atomic)
            }
        } catch {
            os_log(
                "[DXcore] ERROR: Writing Log File: %@", log: .default, type: .error,
                error.localizedDescription)
        }
    }

    private func startTun2socks(completionHandler: @escaping (Bool) -> Void) {

        let config = """
            tunnel:
                mtu: 1280
                ipv4: 198.18.0.1
                ipv6: 'fc00::1'

            socks5:
                port: 5000
                address: 127.0.0.1
                udp: 'udp'
                pipeline: true

            misc:
                task-stack-size: 2048
                tcp-buffer-size: 1024
                connect-timeout: 5000
                read-write-timeout: 5000
                log-file: stderr
                log-level: warn
            """

        os_log("✅ Starting Tunnel")

        Socks5Tunnel.run(withConfig: .string(content: config)) { result in
            NSLog("Tunnel Code: \(result)")
            NSLog("tunnel started...")
        }
        completionHandler(true)
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
