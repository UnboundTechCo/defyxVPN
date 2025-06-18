import NetworkExtension

class VpnService {
    static let shared = VpnService()
    private init() {}
    
    func connect() {
        // Dummy implementation - no actual VPN connection
    }
    
    func disconnect() {
        // Dummy implementation - no actual VPN disconnection
    }
    
    func getStatus() -> String {
        // Always return disconnected in dummy implementation
        return "disconnected"
    }
}
