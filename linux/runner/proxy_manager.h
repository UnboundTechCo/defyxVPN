#pragma once

#include <string>

namespace proxy {

struct ProxyConfig {
  std::string host;
  int port;
  std::string scheme;
  std::string no_proxy;
};

// Applies system proxy settings based on the provided configuration.
// Returns true on success, false otherwise.
bool ApplySystemProxy(const ProxyConfig& config);

// Restores the previously captured system proxy configuration, if any.
void ResetSystemProxy();

// If a previous run left a snapshot on disk, attempt to restore it.
void RestorePendingSnapshot();

}  // namespace proxy
