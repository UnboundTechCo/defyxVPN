import IosDXcore
import NetworkExtension
import Tun2SocksKit
import os.log
import Darwin

// Helper functions for fd_set operations
private func fd_zero(_ set: inout fd_set) {
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

private func fd_set(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = Int32(fd % 32)
    let mask = Int32(1 << bitOffset)
    switch intOffset {
    case 0: set.fds_bits.0 = set.fds_bits.0 | mask
    case 1: set.fds_bits.1 = set.fds_bits.1 | mask
    case 2: set.fds_bits.2 = set.fds_bits.2 | mask
    case 3: set.fds_bits.3 = set.fds_bits.3 | mask
    default: break
    }
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var logTimer: Timer?
    private var socksPort: Int32 = 1080
    private var isVPNRunning = false
    private var vpnConfig: VPNConfig?
    
    struct VPNConfig {
        let cacheDir: String
        let flowLine: String
        let pattern: String
        let deepScan: Bool
    }

    override init() {
        super.init()
        let progressStream = ProgressStreamHandler()
        IosSetProgressListener(progressStream)
        IosSetCrashCallback(self)
    }

    override func startTunnel(
        options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("🚀 [DXcore] startTunnel() called")
        
        // Try to load saved VPN config from shared storage
        // Give it a moment if called immediately after app sends START_VPN message
        var attempt = 0
        func tryLoadConfig() {
            if let config = loadVPNConfig() {
                self.vpnConfig = config
                os_log("✅ [DXcore] Loaded VPN config (attempt %d)", attempt + 1)
                startVPNWithConfig(config, completionHandler: completionHandler)
            } else if attempt < 3 {
                attempt += 1
                os_log("⏳ [DXcore] Config not ready, retrying... (attempt %d)", attempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    tryLoadConfig()
                }
            } else {
                os_log("❌ [DXcore] No VPN config found after 3 attempts")
                let error = NSError(domain: "DefyxVPN", code: 1, 
                    userInfo: [NSLocalizedDescriptionKey: "VPN config not found. Please retry connection."])
                completionHandler(error)
            }
        }
        
        tryLoadConfig()
    }
    
    private func startVPNWithConfig(_ config: VPNConfig, completionHandler: @escaping (Error?) -> Void) {
        os_log("🎯 [DXcore] Starting VPN with config")
        
        // Parse protocol from flowLine to determine SOCKS port
        self.socksPort = parseSOCKSPort(from: config.flowLine)
        os_log("📊 [DXcore] Determined SOCKS port: %d", socksPort)
        
        // Network settings
        let mtu = 1280
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

        os_log("⚙️ [DXcore] Applying network settings...")

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                os_log("❌ [DXcore] Failed to set network settings: %@", error.localizedDescription)
                completionHandler(error)
                return
            }
            
            os_log("✅ [DXcore] Network settings applied")
            
            // Start VPN protocol (Psiphon or Vwarp) in background
            DispatchQueue.global(qos: .userInitiated).async {
                os_log("🔄 [DXcore] Starting VPN protocol...")
                IosStartVPN(config.cacheDir, config.flowLine, config.pattern, config.deepScan)
                self.isVPNRunning = true
                os_log("✅ [DXcore] IosStartVPN() called")
                
                // Wait for SOCKS proxy to be ready
                self.waitForSOCKSProxy(timeout: 15.0) { ready in
                    if ready {
                        os_log("✅ [DXcore] SOCKS proxy is ready on port %d", self.socksPort)
                        
                        // Start Tun2Socks bridge
                        self.startTun2socks { success in
                            if success {
                                os_log("✅ [DXcore] Tun2Socks started successfully")
                            } else {
                                os_log("⚠️ [DXcore] Tun2Socks failed to start")
                            }
                        }
                    } else {
                        os_log("⚠️ [DXcore] SOCKS proxy not ready after timeout")
                    }
                }
            }
            
            // Complete startTunnel quickly (within 5 seconds)
            // iOS will kill extension if we take > 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                os_log("✅ [DXcore] startTunnel() completing")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        os_log("⏹ [DXcore] VPN stopped with reason: %d", reason.rawValue)
        os_log("⏹ [DXcore] Stopping VPN tunnel...")
        
        if isVPNRunning {
            IosStopVPN()
            isVPNRunning = false
            os_log("✅ [DXcore] IosStopVPN() called")
        }
        
        Socks5Tunnel.quit()
        os_log("✅ [DXcore] Tun2Socks stopped")
        
        // Clear saved config
        clearVPNConfig()
        
        os_log("✅ [DXcore] Tunnel stopped successfully")
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
                
                os_log("💾 [DXcore] Saving VPN config to shared storage")
                
                // Save config to shared UserDefaults for startTunnel() to read
                let config = VPNConfig(
                    cacheDir: cacheDir,
                    flowLine: flowLine,
                    pattern: pattern,
                    deepScan: deepScanBool
                )
                saveVPNConfig(config)
                
                os_log("✅ [DXcore] VPN config saved")

                let response = "VPN config saved. Ready to start."

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
                let isTest = dict["isTest"] ?? "false"
                let isTestBool = Bool(isTest) ?? false
                let flowLine = IosGetFlowLine(isTestBool)
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
        os_log("🔄 [DXcore] Tunnel waking up...")
        
        // Check if SOCKS proxy is still alive
        checkSOCKSProxy { alive in
            if !alive && self.isVPNRunning {
                os_log("⚠️ [DXcore] SOCKS proxy died during sleep, restarting...")
                
                if let config = self.vpnConfig {
                    IosStopVPN()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        IosStartVPN(config.cacheDir, config.flowLine, config.pattern, config.deepScan)
                        os_log("✅ [DXcore] VPN restarted after wake")
                    }
                }
            } else {
                os_log("✅ [DXcore] SOCKS proxy still alive")
            }
        }
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
        os_log("🌉 [DXcore] Starting Tun2Socks bridge to port %d", socksPort)

        let config = """
            tunnel:
                mtu: 1280
                ipv4: 198.18.0.1
                ipv6: 'fc00::1'

            socks5:
                port: \(socksPort)
                address: 127.0.0.1
                udp: 'udp'
                pipeline: true

            misc:
                task-stack-size: 4096
                tcp-buffer-size: 8192
                connect-timeout: 10000
                read-write-timeout: 30000
                log-file: stderr
                log-level: info
            """

        os_log("✅ [DXcore] Tun2Socks config:\n%@", config)

        Socks5Tunnel.run(withConfig: .string(content: config)) { result in
            os_log("📊 [DXcore] Tun2Socks result code: %d", result)
        }
        
        // Give it a moment to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completionHandler(true)
        }
    }
    
    // MARK: - Helper Functions
    
    private func parseSOCKSPort(from flowLine: String) -> Int32 {
        // Try to parse JSON flowLine to determine protocol
        if let data = flowLine.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let step = json["step"] as? [String: Any],
           let method = step["method"] as? [String: Any],
           let type = method["type"] as? String {
            
            let protocolType = type.lowercased()
            os_log("🔍 [DXcore] Detected protocol: %@", protocolType)
            
            // Map protocol to port
            if protocolType.contains("vwarp") || protocolType.contains("warp") || protocolType.contains("cloudflare") {
                return 1082 // Vwarp port
            } else if protocolType.contains("psiphon") {
                return 1080 // Psiphon port
            }
        }
        
        // Default to Psiphon
        os_log("⚠️ [DXcore] Could not parse protocol, defaulting to port 1080")
        return 1080
    }
    
    private func saveVPNConfig(_ config: VPNConfig) {
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            defaults.set(config.cacheDir, forKey: "vpn_cache_dir")
            defaults.set(config.flowLine, forKey: "vpn_flow_line")
            defaults.set(config.pattern, forKey: "vpn_pattern")
            defaults.set(config.deepScan, forKey: "vpn_deep_scan")
            defaults.synchronize()
        }
    }
    
    private func loadVPNConfig() -> VPNConfig? {
        guard let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn"),
              let cacheDir = defaults.string(forKey: "vpn_cache_dir"),
              let flowLine = defaults.string(forKey: "vpn_flow_line"),
              let pattern = defaults.string(forKey: "vpn_pattern") else {
            return nil
        }
        
        let deepScan = defaults.bool(forKey: "vpn_deep_scan")
        
        return VPNConfig(
            cacheDir: cacheDir,
            flowLine: flowLine,
            pattern: pattern,
            deepScan: deepScan
        )
    }
    
    private func clearVPNConfig() {
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            defaults.removeObject(forKey: "vpn_cache_dir")
            defaults.removeObject(forKey: "vpn_flow_line")
            defaults.removeObject(forKey: "vpn_pattern")
            defaults.removeObject(forKey: "vpn_deep_scan")
            defaults.synchronize()
        }
    }
    
    private func waitForSOCKSProxy(timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        let checkInterval: TimeInterval = 0.5
        
        func check() {
            checkSOCKSProxy { alive in
                if alive {
                    completion(true)
                } else if Date().timeIntervalSince(startTime) < timeout {
                    DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) {
                        check()
                    }
                } else {
                    os_log("⚠️ [DXcore] SOCKS proxy timeout after %.1f seconds", timeout)
                    completion(false)
                }
            }
        }
        
        check()
    }
    
    private func checkSOCKSProxy(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var sockfd: Int32 = -1
            var hints = addrinfo()
            var result: UnsafeMutablePointer<addrinfo>?
            
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM
            
            let portStr = String(self.socksPort)
            guard getaddrinfo("127.0.0.1", portStr, &hints, &result) == 0 else {
                completion(false)
                return
            }
            
            defer { freeaddrinfo(result) }
            
            sockfd = socket(result!.pointee.ai_family, result!.pointee.ai_socktype, result!.pointee.ai_protocol)
            guard sockfd >= 0 else {
                completion(false)
                return
            }
            
            defer { close(sockfd) }
            
            // Set non-blocking
            var flags = fcntl(sockfd, F_GETFL, 0)
            fcntl(sockfd, F_SETFL, flags | O_NONBLOCK)
            
            // Try to connect
            let connectResult = connect(sockfd, result!.pointee.ai_addr, result!.pointee.ai_addrlen)
            
            if connectResult == 0 {
                completion(true)
            } else if errno == EINPROGRESS {
                // Connection in progress, wait a bit
                var timeout = timeval(tv_sec: 0, tv_usec: 100000) // 100ms
                var writefds = fd_set()
                fd_zero(&writefds)
                fd_set(sockfd, &writefds)
                
                let selectResult = select(sockfd + 1, nil, &writefds, nil, &timeout)
                completion(selectResult > 0)
            } else {
                completion(false)
            }
        }
    }
}

// MARK: - Crash Listener

extension PacketTunnelProvider: IosCrashListenerProtocol {
    func onCrash(_ functionName: String?, errorMessage: String?, stackTrace: String?) {
        os_log("💥 [DXcore] CRASH: %@ - %@", functionName ?? "unknown", errorMessage ?? "no message")
        
        // Log to shared storage
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            var crashes = defaults.stringArray(forKey: "vpn_crashes") ?? []
            let crashLog = "[\(Date())] \(functionName ?? "unknown"): \(errorMessage ?? "no message")"
            crashes.append(crashLog)
            defaults.set(crashes, forKey: "vpn_crashes")
            defaults.synchronize()
        }
        
        // Attempt restart after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, let config = self.vpnConfig else { return }
            
            os_log("🔄 [DXcore] Attempting restart after crash...")
            IosStopVPN()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                IosStartVPN(config.cacheDir, config.flowLine, config.pattern, config.deepScan)
                os_log("✅ [DXcore] VPN restarted after crash")
            }
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
