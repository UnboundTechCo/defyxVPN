#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace defyx_cli {

struct HealthCheckSettings {
  std::string proxy_address = "127.0.0.1";
  uint16_t proxy_port = 5000;
  std::string url;
  uint64_t minimum_bytes = 0;
  int timeout_seconds = 20;
  std::string curl_executable = "curl";
};

struct HealthCheckResult {
  bool healthy = false;
  int http_status = 0;
  uint64_t downloaded_bytes = 0;
  int exit_code = -1;
  std::string error;
};

HealthCheckResult RunHttpsHealthCheck(
    const HealthCheckSettings& settings);
std::vector<std::string> SplitConnectionMethods(
    const std::string& pattern);

}  // namespace defyx_cli
