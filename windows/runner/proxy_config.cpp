#include "proxy_config.h"

#include <wininet.h>
#include <ras.h>
#include <raserror.h>

#pragma comment(lib, "wininet.lib")
#pragma comment(lib, "rasapi32.lib")

ProxyConfig::ProxyConfig() {}

ProxyConfig::~ProxyConfig() {
  // Restore proxy settings on cleanup
  if (proxy_enabled_) {
    DisableProxy();
  }
}

bool ProxyConfig::EnableProxy(const std::string& proxy_address, bool use_socks) {
  if (proxy_enabled_) {
    return true;  // Already enabled
  }

  // Save original proxy settings
  INTERNET_PER_CONN_OPTION_LISTA list;
  DWORD dwBufSize = sizeof(list);
  
  list.dwSize = sizeof(list);
  list.pszConnection = NULL; // LAN connection
  list.dwOptionCount = 2;
  
  INTERNET_PER_CONN_OPTIONA options[2];
  list.pOptions = options;
  
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  
  if (InternetQueryOptionA(NULL, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, &dwBufSize)) {
    if (options[0].Value.dwValue & PROXY_TYPE_PROXY) {
      had_original_proxy_ = true;
      if (options[1].Value.pszValue) {
        original_proxy_ = options[1].Value.pszValue;
        GlobalFree(options[1].Value.pszValue);
      }
    }
  }

  // Enable proxy with HTTP or SOCKS5
  std::string proxy_setting;
  if (use_socks) {
    proxy_setting = "socks=" + proxy_address;
  } else {
    proxy_setting = proxy_address;
  }
  
  if (SetInternetProxy(true, proxy_setting)) {
    proxy_enabled_ = true;
    NotifyProxyChange();
    return true;
  }
  
  return false;
}

bool ProxyConfig::DisableProxy() {
  if (!proxy_enabled_) {
    return true;  // Already disabled
  }

  bool success;
  if (had_original_proxy_) {
    // Restore original proxy
    success = SetInternetProxy(true, original_proxy_);
  } else {
    // Disable proxy completely
    success = SetInternetProxy(false);
  }

  if (success) {
    proxy_enabled_ = false;
    NotifyProxyChange();
  }

  return success;
}

bool ProxyConfig::IsProxyEnabled() const {
  return proxy_enabled_;
}

bool ProxyConfig::SetInternetProxy(bool enable, const std::string& proxy_server) {
  INTERNET_PER_CONN_OPTION_LISTA list;
  DWORD dwBufSize = sizeof(list);
  
  list.dwSize = sizeof(list);
  list.pszConnection = NULL; // LAN connection
  list.dwOptionCount = enable ? 2 : 1;
  
  INTERNET_PER_CONN_OPTIONA options[2];
  list.pOptions = options;
  
  if (enable) {
    options[0].dwOption = INTERNET_PER_CONN_FLAGS;
    options[0].Value.dwValue = PROXY_TYPE_PROXY | PROXY_TYPE_DIRECT;
    
    options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
    options[1].Value.pszValue = const_cast<char*>(proxy_server.c_str());
  } else {
    options[0].dwOption = INTERNET_PER_CONN_FLAGS;
    options[0].Value.dwValue = PROXY_TYPE_DIRECT;
  }
  
  bool result = InternetSetOptionA(NULL, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, dwBufSize);
  
  return result;
}

bool ProxyConfig::NotifyProxyChange() {
  // Notify all applications of proxy settings change
  InternetSetOptionA(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
  InternetSetOptionA(NULL, INTERNET_OPTION_REFRESH, NULL, 0);
  
  return true;
}
