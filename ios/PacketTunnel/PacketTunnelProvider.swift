import IosDXcore
import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let tunnelAddress = "172.18.0.1"
    private let tunnelMask = "255.255.255.252"
    private let tunnelDns = "1.1.1.1"
    private let tunnelMtu = 1500

    private var logTimer: Timer?

    override init() {
        super.init()
        let progressStream = ProgressStreamHandler()
        IosSetProgressListener(progressStream)
    }

    override func startTunnel(
        options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("Starting sing-box tunnel...")

        setTunnelNetworkSettings(tunnelSettings()) { error in
            if let error = error {
                os_log("Failed to apply tunnel settings: %{public}@", error.localizedDescription)
                completionHandler(error)
                return
            }

            let success = IosStartTunnel(0)

            if success {
                os_log("Tunnel started successfully")
                completionHandler(nil)
            } else {
                os_log("Failed to start tunnel")
                let startError = NSError(
                    domain: "PacketTunnelProvider",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start sing-box tunnel"]
                )
                completionHandler(startError)
            }
        }
    }

    private func tunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)

        let ipv4 = NEIPv4Settings(addresses: [tunnelAddress], subnetMasks: [tunnelMask])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: [tunnelDns])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        settings.mtu = NSNumber(value: tunnelMtu)

        return settings
    }

    override func stopTunnel(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        os_log("VPN stopped with reason: %d", reason.rawValue)
        os_log("Stopping VPN tunnel...")
        IosStopTunnel()
        IosStopVPN()
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

        switch command {
        case "START_TUNNEL":
            let success = IosStartTunnel(0)
            let response = success ? "TUNNEL_STARTED" : "TUNNEL_ERROR"
            os_log("Tunnel: %{public}@", response)
            completionHandler?(response.data(using: .utf8))

        case "MEASURE_PING":
            do {
                let ping = IosMeasurePing()
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
                let flag = IosGetFlag()
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
                let deepScan = dict["deepScan"] ?? "false"
                let deepScanBool = Bool(deepScan) ?? false
                let healthCheck = dict["healthCheck"] ?? "false"
                let healthCheckBool = Bool(healthCheck) ?? false

                IosStartVPN(cacheDir, flowLine, pattern,deepScanBool, healthCheckBool)

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
                IosStopVPN()
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
                IosSetAsnName()
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
                let success = IosSetTimeZone(timezoneFloat)

                let response: String
                if success {
                    os_log("local time zone set successfully")
                    response = "LOCAL_TIMEZONE_SET"
                } else {
                    os_log(
                        "Failed to set local time zone: %{public}@", String(describing: success))
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
                let isTest = dict["isTest"] ?? "false"
                let isTestBool = Bool(isTest) ?? false
                let token = dict["token"] ?? ""
                let flowLine = IosGetFlowLine(isTestBool, token)
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
        case "GET_CACHED_FLOW_LINE":
            do {
                let flowLine = IosGetCachedFlowLine()
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
                
                }catch {
                print("Error: \(error.localizedDescription)")
                completionHandler?(nil)
            }

        case "DECODE_VERIFY_FLOWLINE":
            do {
                let flowLine = dict["flowLine"] ?? ""
                let decodedFlowLine = IosDecodeAndVerifyFlowline(flowLine)
                let response: String = decodedFlowLine

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

        case "SET_CACHE_DIR":
            do {
                let cacheDir = dict["cacheDir"] ?? ""
                IosSetCacheDir(cacheDir)
                
                if let data = "true".data(using: .utf8) {
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
}

class ProgressStreamHandler: NSObject, IosProgressListenerProtocol {
    func onProgress(_ msg: String?) {
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            var logs = defaults.stringArray(forKey: "vpn_logs") ?? []
            logs.append(msg ?? "")
            defaults.set(logs, forKey: "vpn_logs")
            defaults.synchronize()
        }
    }
}
