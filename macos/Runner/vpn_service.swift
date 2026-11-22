import Foundation
import NetworkExtension
import Combine

@available(macOS 11.0, *)
class VpnService {
    static let shared = VpnService()

    private var vpnManager: NETunnelProviderManager?
    private var cancellables = Set<AnyCancellable>()
    private var vpnStatusCancellable: AnyCancellable?
    
    weak var statusDelegate: VpnStatusDelegate?

    private init() {}

    var manager: NETunnelProviderManager? {
        get { vpnManager }
        set { vpnManager = newValue }
    }

    func prepareVPN(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let managers = try await NETunnelProviderManager.loadAllFromPreferences()
                print("✅ VPN Manager loaded")
                if managers.isEmpty {
                    print("⚠️ No existing VPN manager found")
                    vpnManager = NETunnelProviderManager()
                    print("✅ VPN Manager created:")
                    try configureVPNManager(vpnManager!)
                    print("✅ VPN Manager configured")
                    try await vpnManager?.saveToPreferences()
                    print("✅ VPN Manager saved")
                } else {
                    vpnManager = managers.first
                    print("✅ VPN Manager found: \(vpnManager?.localizedDescription ?? "Unknown")")
                }
                print("✅ VPN Manager prepared")

                try await vpnManager?.loadFromPreferences()
                observeVPNStatus(vpnManager!)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // Like prepareVPN, but never creates the profile, so it never asks the
    // user for permission.
    func isVPNPrepared(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let managers = try await NETunnelProviderManager.loadAllFromPreferences()
                guard let manager = managers.first else {
                    completion(.failure(NSError(
                        domain: "DefyxVPN", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "VPN Manager not initialized"])))
                    return
                }
                vpnManager = manager
                try await manager.loadFromPreferences()
                observeVPNStatus(manager)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func configureVPNManager(_ manager: NETunnelProviderManager) throws {
        manager.localizedDescription = "DefyxVPN"
        
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = "de.unboundtech.defyxvpn.PacketTunnel"
        protocolConfig.serverAddress = "localhost"

        let configData: [String: Any] = [
            "address": "127.0.0.1",
            "port": 5000,
            "mtu": 1280
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: configData) {
            protocolConfig.providerConfiguration = ["config": data]
        }
        
        protocolConfig.excludeLocalNetworks = true
        manager.protocolConfiguration = protocolConfig
        manager.isEnabled = true
        manager.isOnDemandEnabled = false
        manager.onDemandRules = []
    }

    func startVPN(port: Int32, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let manager = vpnManager else {
                    throw NSError(domain: "DefyxVPN", code: 0, userInfo: [NSLocalizedDescriptionKey: "VPN Manager not initialized"])
                }

                try configureVPNManager(manager)
                try await manager.saveToPreferences()
                try await Task.sleep(nanoseconds: 1_000_000_000)

                try await manager.loadFromPreferences()

                if manager.connection.status == .connected || manager.connection.status == .connecting {
                    manager.connection.stopVPNTunnel()
                    print("🔄 VPN disconnected before reconnecting.")
                    try await Task.sleep(nanoseconds: 500_000_000) 
                }
                
                let options: [String: NSObject] = [
                    "port": NSNumber(value: port),
                    "address": "127.0.0.1" as NSString,
                    "mtu": NSNumber(value: 1280),
                ]
                
                try manager.connection.startVPNTunnel(options: options)
                print("✅ Starting VPN connection")
                completion(.success(()))
            } catch {
                print("❌ Start VPN error: \(error)")
                completion(.failure(error))
            }
        }
    }

    func stopVPN(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let manager = vpnManager else {
                    throw NSError(domain: "DefyxVPN", code: 0, userInfo: [NSLocalizedDescriptionKey: "VPN Manager not initialized"])
                }
                try await manager.loadFromPreferences()

                if manager.connection.status == .connected || manager.connection.status == .connecting {
                    manager.connection.stopVPNTunnel()
                    print("🛑 VPN stopped")
                    completion(.success(()))
                } else {
                    print("ℹ️ VPN is already stopped. Current status: \(manager.connection.status.rawValue)")
                    completion(.success(()))
                }
            } catch {
                print("❌ Stop VPN error: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func observeVPNStatus(_ manager: NETunnelProviderManager) {
        vpnStatusCancellable?.cancel()
        
        vpnStatusCancellable = NotificationCenter.default.publisher(for: .NEVPNStatusDidChange, object: manager.connection)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let status = manager.connection.status
                self.updateVPNStatus(status)
                self.statusDelegate?.vpnStatusDidChange(status)
            }
    }

    private func updateVPNStatus(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            print("✅ VPN Connected")
        case .disconnected:
            print("🛑 VPN Disconnected")
        case .connecting:
            print("⏳ VPN Connecting...")
        case .disconnecting:
            print("🔄 VPN Disconnecting...")
        case .reasserting:
            print("🔄 VPN Reasserting...")
        case .invalid:
            print("⚠️ VPN Status Invalid")
        @unknown default:
            print("❓ VPN Unknown Status: \(status.rawValue)")
        }
    }

    func loadManager(completion: @escaping (Bool) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("❌ Failed to load managers: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let managers = managers, !managers.isEmpty {
                self.vpnManager = managers.first
                print("✅ Loaded existing VPN manager")
                if let manager = self.vpnManager {
                    self.observeVPNStatus(manager)
                }
                completion(true)
            } else {
                print("⚠️ No existing VPN manager found")
                completion(false)
            }
        }
    }

    func sendTunnelMessage(_ messageDict: [String: String], completion: ((String?) -> Void)? = nil) {
        guard let manager = vpnManager else {
            print("❌ VPN Manager is not initialized")
            completion?(nil)
            return
        }

        Task {
            do {
                try await manager.loadFromPreferences()

                guard let session = manager.connection as? NETunnelProviderSession else {
                    print("❌ Invalid VPN connection")
                    completion?(nil)
                    return
                }

                guard let data = try? JSONSerialization.data(withJSONObject: messageDict) else {
                    print("❌ Failed to encode message")
                    completion?(nil)
                    return
                }

                try session.sendProviderMessage(data) { responseData in
                    if let responseData = responseData,
                       let responseString = String(data: responseData, encoding: .utf8) {
                        completion?(responseString)
                    } else {
                        print("❌ No response or invalid response")
                        completion?(nil)
                    }
                }
            } catch {
                print("❌ Error sending tunnel message: \(error)")
                completion?(nil)
            }
        }
    }
}

@available(macOS 11.0, *)
protocol VpnStatusDelegate: AnyObject {
    func vpnStatusDidChange(_ status: NEVPNStatus)
}