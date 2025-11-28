#pragma once

#include <string>
#include <windows.h>

class ProxyConfig {
 public:
  ProxyConfig();
  ~ProxyConfig();

  // Enable system-wide proxy for the SOCKS5 server
  bool EnableProxy(const std::string& socks_address);
  
  // Disable system-wide proxy and restore original settings
  bool DisableProxy();
  
  // Check if proxy is currently enabled
  bool IsProxyEnabled() const;

 private:
  bool SetInternetProxy(bool enable, const std::string& proxy_server = "");
  bool NotifyProxyChange();
  
  bool proxy_enabled_ = false;
  std::string original_proxy_;
  bool had_original_proxy_ = false;
};
