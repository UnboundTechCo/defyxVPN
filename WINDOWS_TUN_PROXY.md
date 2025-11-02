# Windows TUN/Proxy Implementation

## Problem
On Windows, the app only had a SOCKS5 proxy running on port 5000, but no system-wide TUN adapter to route all traffic through the VPN.

## Solution
Since DXcore uses a userspace network stack (netstack) instead of kernel-level TUN, we implemented automatic system proxy configuration that routes all Windows traffic through the SOCKS5 proxy.

## How It Works

### Architecture
```
Application Traffic
       ↓
Windows System Proxy (Auto-configured)
       ↓
SOCKS5 Proxy (127.0.0.1:5000)
       ↓
DXcore netstack (Userspace)
       ↓
WireGuard/Xray VPN Server
```

### Components

1. **ProxyConfig Class** (`proxy_config.h/cpp`)
   - Automatically enables/disables Windows system proxy
   - Saves and restores original proxy settings
   - Configures SOCKS5 proxy on 127.0.0.1:5000
   - Uses WinINet API for system-wide proxy control

2. **Integration** (`flutter_window.cpp`)
   - Proxy is enabled when VPN connects (on "Data: VPN connected" message)
   - Proxy is disabled when VPN disconnects
   - Automatic cleanup on app exit

### Advantages
- ✅ No administrator privileges required
- ✅ No kernel drivers needed (WinTun not required)
- ✅ Works with existing DXcore netstack implementation
- ✅ Automatic proxy restoration
- ✅ Compatible with all Windows versions

### Limitations
- ⚠️ Not all applications respect system proxy (e.g., some games, P2P apps)
- ⚠️ UDP traffic requires application-level SOCKS5 support
- ⚠️ DNS may leak if applications don't use proxy for DNS

## Alternative: Full TUN with WinTun (Advanced)

For a true system-wide VPN that captures ALL traffic including UDP and non-proxy-aware apps, you would need:

### Option 1: WinTun Driver
```
1. Download WinTun driver from https://www.wintun.net/
2. Implement TUN adapter creation in DXcore
3. Route all traffic through TUN interface
4. Requires admin privileges to install driver
```

### Option 2: Use V2Ray/Xray TUN Mode
The xray-core already has TUN support. You could:
1. Enable TUN mode in Xray configuration
2. Let Xray handle the TUN adapter
3. This requires admin rights on Windows

## Current Implementation

The current SOCKS5 proxy approach is the **recommended solution** because:
- Works without admin rights
- Simple to implement and maintain
- Sufficient for most use cases (web browsing, HTTP/HTTPS apps)
- Compatible with DXcore's existing netstack architecture

## Testing

1. Connect to VPN
2. Check Windows Internet Settings → LAN Settings → Proxy Server
3. You should see: "Address: 127.0.0.1:5000" with "Use a proxy server" enabled
4. Open browser, navigate to https://api.ipify.org/ - should show VPN IP
5. Disconnect VPN - proxy settings should be restored

## Troubleshooting

**Proxy not working?**
- Check if app respects system proxy settings
- Some apps need manual SOCKS5 configuration
- Check Windows Event Viewer for proxy-related errors

**Proxy not disabled after disconnect?**
- The ProxyConfig destructor handles cleanup
- Manually check: Settings → Network → Proxy → Manual proxy setup

**Want to capture ALL traffic?**
- Consider implementing WinTun integration (requires admin)
- Or use Xray's built-in TUN mode (also requires admin)
