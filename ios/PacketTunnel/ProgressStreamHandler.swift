//
//  ProgressStreamHandler.swift
//  PacketTunnel
//
//  Created on 2026-03-19.
//  VPN event handling and progress listener implementation
//

import Foundation
import IosDXcore
import os.log

/// VPN event structure for structured communication from Go cores
struct VPNEvent {
    let event: String
    let core: String
    let data: [String: Any]
}

/// Progress listener that receives messages from Go VPN cores
/// Handles both structured JSON events and plain log messages
class ProgressStreamHandler: NSObject, IosProgressListenerProtocol {
    weak var provider: PacketTunnelProvider?
    
    init(provider: PacketTunnelProvider) {
        self.provider = provider
        super.init()
        os_log("🎯 [HANDLER-INIT] ProgressStreamHandler initialized")
    }
    
    func onProgress(_ msg: String?) {
        os_log("🔔 [PROGRESS-ENTRY] onProgress() CALLED!")
        
        guard let message = msg else {
            os_log("⚠️ [PROGRESS] Received nil message")
            return
        }
        
        os_log("🔵 [PROGRESS] Received message (length: %d): %@", message.count, message)
        
        // Try to parse as VPN event (JSON)
        if let event = parseVPNEvent(message) {
            os_log("✅ [PROGRESS] Successfully parsed as VPN event")
            handleVPNEvent(event)
            return
        }
        
        os_log("🔵 [PROGRESS] Not a VPN event, treating as log message")
        // Otherwise treat as regular log message
        logMessage(message)
    }
    
    private func parseVPNEvent(_ message: String) -> VPNEvent? {
        os_log("🔵 [PARSE] Attempting to parse as JSON...")
        guard let data = message.data(using: .utf8) else {
            os_log("❌ [PARSE] Failed to convert to UTF8 data")
            return nil
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            os_log("❌ [PARSE] Failed to deserialize JSON")
            return nil
        }
        os_log("✅ [PARSE] Deserialized JSON: %@", String(describing: json))
        
        guard let event = json["event"] as? String,
              let core = json["core"] as? String else {
            os_log("❌ [PARSE] Missing 'event' or 'core' field")
            return nil
        }
        
        let eventData = json["data"] as? [String: Any] ?? [:]
        os_log("✅ [PARSE] Parsed VPNEvent - event: %@, core: %@", event, core)
        return VPNEvent(event: event, core: core, data: eventData)
    }
    
    private func handleVPNEvent(_ event: VPNEvent) {
        os_log("📡 [EVENT] VPN Event: %@ from %@, data: %@", event.event, event.core, String(describing: event.data))
        
        switch event.event {
        case "PROXY_READY":
            handleProxyReady(event)
        case "TUNNEL_CONNECTED":
            os_log("✅ [EVENT] Tunnel connected: %@", event.core)
        case "TUNNEL_FAILED":
            os_log("❌ [EVENT] Tunnel failed: %@", event.core)
        default:
            os_log("⚠️ [EVENT] Unknown event type: %@", event.event)
        }
    }
    
    private func handleProxyReady(_ event: VPNEvent) {
        os_log("🎯🎯🎯 [PROXY_READY] handleProxyReady() CALLED!")
        let port = event.data["port"] as? Int ?? 5000
        os_log("✅ [PROXY_READY] Proxy ready on port %d from core: %@", port, event.core)
        os_log("🔵 [PROXY_READY] Waiting 0.2s for stabilization...")
        
        // Small delay to ensure proxy is fully accepting connections
        // gVisor doesn't retry connection attempts, so we need to ensure port is truly ready
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.2
        ) { [weak self] in
            os_log("🔵 [PROXY_READY] Stabilization complete, starting tun2socks...")
            self?.provider?.startTun2socks { success in
                if success {
                    os_log("✅ [PROXY_READY] Tun2socks connected to %@ proxy", event.core)
                } else {
                    os_log("❌ [PROXY_READY] Tun2socks failed to start!")
                }
            }
        }
    }
    
    private func logMessage(_ message: String) {
        if let defaults = UserDefaults(suiteName: "group.de.unboundtech.defyxvpn") {
            var logs = defaults.stringArray(forKey: "vpn_logs") ?? []
            logs.append(message)
            defaults.set(logs, forKey: "vpn_logs")
            defaults.synchronize()
        }
    }
}
