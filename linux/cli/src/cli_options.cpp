#include "cli_options.h"
#include "tcp_forwarder.h"

#include <cerrno>
#include <climits>
#include <cstdlib>
#include <sstream>
#include <string>

#include <unistd.h>

namespace defyx_cli {

namespace {

std::string GetEnvironment(const char* name) {
  const char* value = std::getenv(name);
  return value == nullptr ? std::string() : std::string(value);
}

bool ParseBoolean(const std::string& value, bool fallback) {
  if (value == "1" || value == "true" || value == "yes" || value == "on") {
    return true;
  }
  if (value == "0" || value == "false" || value == "no" || value == "off") {
    return false;
  }
  return fallback;
}

bool ParseNonNegativeInteger(const std::string& value, int* result) {
  if (value.empty() || result == nullptr) {
    return false;
  }

  char* end = nullptr;
  errno = 0;
  const long parsed = std::strtol(value.c_str(), &end, 10);
  if (errno != 0 || end == value.c_str() || *end != '\0' || parsed < 0 ||
      parsed > INT_MAX) {
    return false;
  }

  *result = static_cast<int>(parsed);
  return true;
}

bool ParsePort(const std::string& value, int* result) {
  int parsed = 0;
  if (!ParseNonNegativeInteger(value, &parsed) || parsed == 0 ||
      parsed > 65535) {
    return false;
  }
  *result = parsed;
  return true;
}

bool IsHttpsUrl(const std::string& value) {
  return value.size() > 8 && value.compare(0, 8, "https://") == 0;
}

std::string DefaultCacheDirectory() {
  std::string cache_home = GetEnvironment("XDG_CACHE_HOME");
  if (!cache_home.empty()) {
    return cache_home + "/defyxvpn";
  }

  std::string home = GetEnvironment("HOME");
  if (!home.empty()) {
    return home + "/.cache/defyxvpn";
  }

  return "/tmp/defyxvpn-" + std::to_string(static_cast<long long>(getuid()));
}

bool ReadValue(const std::vector<std::string>& arguments, size_t* index,
               const std::string& option, std::string* value,
               std::string* error) {
  if (*index + 1 >= arguments.size()) {
    *error = option + " requires a value";
    return false;
  }
  *value = arguments[++(*index)];
  if (value->empty()) {
    *error = option + " requires a non-empty value";
    return false;
  }
  return true;
}

}  // namespace

Options OptionsFromEnvironment() {
  Options options;
  options.core_library = GetEnvironment("DEFYX_CORE_LIB");
  options.flowline_file = GetEnvironment("DEFYX_FLOWLINE_FILE");
  options.pattern = GetEnvironment("DEFYX_PATTERN");

  const std::string listen_address = GetEnvironment("DEFYX_LISTEN_ADDRESS");
  if (!listen_address.empty()) {
    options.listen_address = listen_address;
  }
  const std::string listen_port = GetEnvironment("DEFYX_LISTEN_PORT");
  if (!listen_port.empty() &&
      !ParsePort(listen_port, &options.listen_port)) {
    options.listen_port = 0;
  }

  options.cache_directory = GetEnvironment("DEFYX_CACHE_DIR");
  if (options.cache_directory.empty()) {
    options.cache_directory = DefaultCacheDirectory();
  }

  options.deep_scan =
      ParseBoolean(GetEnvironment("DEFYX_DEEP_SCAN"), options.deep_scan);
  options.health_check =
      ParseBoolean(GetEnvironment("DEFYX_HEALTH_CHECK"), options.health_check);
  const std::string health_check_url =
      GetEnvironment("DEFYX_HEALTH_CHECK_URL");
  if (!health_check_url.empty()) {
    options.health_check_url = health_check_url;
  }
  const std::string health_check_min_bytes =
      GetEnvironment("DEFYX_HEALTH_CHECK_MIN_BYTES");
  if (!health_check_min_bytes.empty() &&
      !ParseNonNegativeInteger(health_check_min_bytes,
                               &options.health_check_min_bytes)) {
    options.health_check_min_bytes = -1;
  }
  const std::string health_check_timeout =
      GetEnvironment("DEFYX_HEALTH_CHECK_TIMEOUT");
  if (!health_check_timeout.empty() &&
      (!ParseNonNegativeInteger(health_check_timeout,
                                &options.health_check_timeout_seconds) ||
       options.health_check_timeout_seconds == 0)) {
    options.health_check_timeout_seconds = 0;
  }
  const std::string health_check_interval =
      GetEnvironment("DEFYX_HEALTH_CHECK_INTERVAL");
  if (!health_check_interval.empty() &&
      !ParseNonNegativeInteger(health_check_interval,
                               &options.health_check_interval_seconds)) {
    options.health_check_interval_seconds = -1;
  }
  const std::string health_check_failures =
      GetEnvironment("DEFYX_HEALTH_CHECK_FAILURES");
  if (!health_check_failures.empty() &&
      (!ParseNonNegativeInteger(health_check_failures,
                                &options.health_check_failures) ||
       options.health_check_failures == 0)) {
    options.health_check_failures = 0;
  }
  options.cached_flowline = ParseBoolean(
      GetEnvironment("DEFYX_CACHED_FLOWLINE"), options.cached_flowline);
  options.test_flowline =
      ParseBoolean(GetEnvironment("DEFYX_TEST_FLOWLINE"), options.test_flowline);
  options.verbose =
      ParseBoolean(GetEnvironment("DEFYX_VERBOSE"), options.verbose);
  options.quiet = ParseBoolean(GetEnvironment("DEFYX_QUIET"), options.quiet);

  const std::string timeout = GetEnvironment("DEFYX_CONNECT_TIMEOUT");
  if (!timeout.empty()) {
    ParseNonNegativeInteger(timeout, &options.timeout_seconds);
  }

  return options;
}

ParseResult ParseOptions(const std::vector<std::string>& arguments,
                         const Options& defaults) {
  ParseResult result;
  result.options = defaults;

  bool command_set = false;
  for (size_t index = 0; index < arguments.size(); ++index) {
    const std::string& argument = arguments[index];

    if (argument == "-h" || argument == "--help") {
      result.options.command = Command::help;
      return result;
    }
    if (argument == "-v" || argument == "--version") {
      result.options.command = Command::version;
      return result;
    }
    if (argument == "--core-lib") {
      if (!ReadValue(arguments, &index, argument,
                     &result.options.core_library, &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--cache-dir") {
      if (!ReadValue(arguments, &index, argument,
                     &result.options.cache_directory, &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--flowline-file") {
      if (!ReadValue(arguments, &index, argument,
                     &result.options.flowline_file, &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--pattern") {
      if (!ReadValue(arguments, &index, argument, &result.options.pattern,
                     &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--listen-address" || argument == "--listen-ip") {
      if (!ReadValue(arguments, &index, argument,
                     &result.options.listen_address, &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--listen-port") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParsePort(value, &result.options.listen_port)) {
        result.error = "--listen-port must be a number from 1 to 65535";
        return result;
      }
      continue;
    }
    if (argument == "--timeout") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParseNonNegativeInteger(value, &result.options.timeout_seconds)) {
        result.error = "--timeout must be a non-negative number of seconds";
        return result;
      }
      continue;
    }
    if (argument == "--deep-scan") {
      result.options.deep_scan = true;
      continue;
    }
    if (argument == "--health-check") {
      result.options.health_check = true;
      continue;
    }
    if (argument == "--health-check-url") {
      if (!ReadValue(arguments, &index, argument,
                     &result.options.health_check_url, &result.error)) {
        return result;
      }
      continue;
    }
    if (argument == "--health-check-min-bytes") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParseNonNegativeInteger(
              value, &result.options.health_check_min_bytes)) {
        result.error =
            "--health-check-min-bytes must be a non-negative number";
        return result;
      }
      continue;
    }
    if (argument == "--health-check-timeout") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParseNonNegativeInteger(
              value, &result.options.health_check_timeout_seconds) ||
          result.options.health_check_timeout_seconds == 0) {
        result.error =
            "--health-check-timeout must be a positive number of seconds";
        return result;
      }
      continue;
    }
    if (argument == "--health-check-interval") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParseNonNegativeInteger(
              value, &result.options.health_check_interval_seconds)) {
        result.error =
            "--health-check-interval must be a non-negative number of seconds";
        return result;
      }
      continue;
    }
    if (argument == "--health-check-failures") {
      std::string value;
      if (!ReadValue(arguments, &index, argument, &value, &result.error)) {
        return result;
      }
      if (!ParseNonNegativeInteger(
              value, &result.options.health_check_failures) ||
          result.options.health_check_failures == 0) {
        result.error =
            "--health-check-failures must be a positive number";
        return result;
      }
      continue;
    }
    if (argument == "--cached-flowline") {
      result.options.cached_flowline = true;
      continue;
    }
    if (argument == "--test-flowline") {
      result.options.test_flowline = true;
      continue;
    }
    if (argument == "--verbose") {
      result.options.verbose = true;
      continue;
    }
    if (argument == "--quiet") {
      result.options.quiet = true;
      continue;
    }

    if (!argument.empty() && argument.front() == '-') {
      result.error = "unknown option: " + argument;
      return result;
    }
    if (command_set) {
      result.error = "unexpected argument: " + argument;
      return result;
    }

    command_set = true;
    if (argument == "connect" || argument == "start") {
      result.options.command = Command::connect;
    } else if (argument == "status") {
      result.options.command = Command::status;
    } else if (argument == "disconnect" || argument == "stop") {
      result.options.command = Command::disconnect;
    } else if (argument == "help") {
      result.options.command = Command::help;
    } else if (argument == "version") {
      result.options.command = Command::version;
    } else {
      result.error = "unknown command: " + argument;
      return result;
    }
  }

  if (!command_set) {
    result.options.command = Command::help;
  }
  if (!IsIpAddress(result.options.listen_address)) {
    result.error =
        "--listen-address must be a literal IPv4 or IPv6 address";
    return result;
  }
  if (result.options.listen_port <= 0 ||
      result.options.listen_port > 65535) {
    result.error = "--listen-port must be a number from 1 to 65535";
  }
  if (!IsHttpsUrl(result.options.health_check_url)) {
    result.error = "--health-check-url must use https://";
  }
  if (result.options.health_check_min_bytes < 0) {
    result.error =
        "--health-check-min-bytes must be a non-negative number";
  }
  if (result.options.health_check_timeout_seconds <= 0) {
    result.error =
        "--health-check-timeout must be a positive number of seconds";
  }
  if (result.options.health_check_interval_seconds < 0) {
    result.error =
        "--health-check-interval must be a non-negative number of seconds";
  }
  if (result.options.health_check_failures <= 0) {
    result.error =
        "--health-check-failures must be a positive number";
  }
  return result;
}

std::string Usage() {
  return R"(DefyxVPN headless client

Usage:
  defyxvpn-cli connect [options]
  defyxvpn-cli status [--cache-dir PATH]
  defyxvpn-cli disconnect [--cache-dir PATH]
  defyxvpn-cli version

Connect options:
  --core-lib PATH        Path to libdxcore_amd64.so
  --cache-dir PATH       Runtime/cache directory
  --flowline-file PATH   Signed flowline export, full response, or raw config
  --pattern LABELS       Comma-separated connection method labels
  --listen-address IP    SOCKS5 listen IP (default: 127.0.0.1)
  --listen-port PORT      SOCKS5 listen port (default: 5000)
  --cached-flowline      Use DXcore's cached flowline
  --test-flowline        Request the test flowline
  --deep-scan            Keep scanning connection methods
  --health-check         Verify HTTPS and try each method until one passes
  --health-check-url URL HTTPS endpoint used for validation
  --health-check-min-bytes N
                         Minimum complete response size (default: 65536)
  --health-check-timeout SECONDS
                         Per-check timeout (default: 20)
  --health-check-interval SECONDS
                         Runtime check interval; 0 disables it (default: 60)
  --health-check-failures N
                         Consecutive failures before failover (default: 2)
  --timeout SECONDS      Stop if not connected in time (0 means no timeout)
  --verbose              Enable verbose DXcore logging
  --quiet                Only print state changes and errors
  -h, --help             Show this help
  -v, --version          Show the version

The same settings can be supplied with DEFYX_CORE_LIB, DEFYX_CACHE_DIR,
DEFYX_FLOWLINE_FILE, DEFYX_PATTERN, DEFYX_CACHED_FLOWLINE,
DEFYX_TEST_FLOWLINE, DEFYX_DEEP_SCAN, DEFYX_HEALTH_CHECK,
DEFYX_HEALTH_CHECK_URL, DEFYX_HEALTH_CHECK_MIN_BYTES,
DEFYX_HEALTH_CHECK_TIMEOUT, DEFYX_HEALTH_CHECK_INTERVAL,
DEFYX_HEALTH_CHECK_FAILURES,
DEFYX_LISTEN_ADDRESS, DEFYX_LISTEN_PORT, DEFYX_CONNECT_TIMEOUT,
DEFYX_VERBOSE, and DEFYX_QUIET.
)";
}

}  // namespace defyx_cli
