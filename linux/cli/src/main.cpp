#include "cli_options.h"
#include "flowline.h"
#include "health_check.h"
#include "progress.h"
#include "status_file.h"
#include "tcp_forwarder.h"

#include "defyx_core.h"

#include <chrono>
#include <condition_variable>
#include <csignal>
#include <cstdint>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <cerrno>
#include <cstring>
#include <unistd.h>

#ifndef DEFYX_CLI_VERSION
#define DEFYX_CLI_VERSION "dev"
#endif

namespace {

constexpr const char* kCoreProxyAddress = "127.0.0.1";
constexpr uint16_t kCoreProxyPort = 5000;
constexpr uintmax_t kMaximumFlowLineSize = 16U * 1024U * 1024U;
constexpr int kNotRunningExitCode = 3;
constexpr int kConnectionFailureExitCode = 4;

volatile std::sig_atomic_t g_shutdown_signal = 0;

void HandleSignal(int signal_number) {
  g_shutdown_signal = signal_number;
}

std::string ReadFile(const std::string& path, std::string* error) {
  std::error_code filesystem_error;
  const uintmax_t size = std::filesystem::file_size(path, filesystem_error);
  if (filesystem_error) {
    if (error != nullptr) {
      *error = "cannot inspect " + path + ": " + filesystem_error.message();
    }
    return {};
  }
  if (size > kMaximumFlowLineSize) {
    if (error != nullptr) {
      *error = "flowline file is larger than 16 MiB";
    }
    return {};
  }

  std::ifstream stream(path, std::ios::in | std::ios::binary);
  if (!stream) {
    if (error != nullptr) {
      *error = "cannot read " + path;
    }
    return {};
  }
  return std::string((std::istreambuf_iterator<char>(stream)),
                     std::istreambuf_iterator<char>());
}

float LocalUtcOffsetHours() {
  const std::time_t now = std::time(nullptr);
  std::tm local_time {};
  std::tm utc_time {};
  localtime_r(&now, &local_time);
  gmtime_r(&now, &utc_time);

  local_time.tm_isdst = -1;
  utc_time.tm_isdst = -1;
  const double seconds =
      std::difftime(std::mktime(&local_time), std::mktime(&utc_time));
  return static_cast<float>(seconds / 3600.0);
}

defyx_cli::FlowLineResult ResolveFlowLine(
    const defyx_cli::Options& options) {
  if (!options.flowline_file.empty()) {
    std::string read_error;
    const std::string file_payload =
        ReadFile(options.flowline_file, &read_error);
    if (!read_error.empty()) {
      defyx_cli::FlowLineResult result;
      result.error = read_error;
      return result;
    }

    // Exported offline flowlines are signed. Prefer the verified representation,
    // while still accepting a raw flowLine object for advanced deployments.
    const std::string verified =
        defyx_core::DecodeAndVerifyFlowline(file_payload);
    if (!verified.empty()) {
      defyx_cli::FlowLineResult result =
          defyx_cli::NormalizeFlowLine(verified);
      if (result.ok()) {
        return result;
      }
    }
    return defyx_cli::NormalizeFlowLine(file_payload);
  }

  std::string payload = options.cached_flowline
                            ? defyx_core::GetCachedFlowLine()
                            : defyx_core::GetFlowLine(options.test_flowline);
  defyx_cli::FlowLineResult result =
      defyx_cli::NormalizeFlowLine(payload);
  if (result.ok() || options.cached_flowline) {
    return result;
  }

  const std::string cached = defyx_core::GetCachedFlowLine();
  defyx_cli::FlowLineResult cached_result =
      defyx_cli::NormalizeFlowLine(cached);
  if (cached_result.ok()) {
    return cached_result;
  }

  result.error += "; cached flowline is also unavailable: " +
                  cached_result.error;
  return result;
}

class RuntimeTracker {
 public:
  RuntimeTracker(std::string cache_directory, bool quiet,
                 std::string endpoint, bool requires_health_check)
      : cache_directory_(std::move(cache_directory)),
        quiet_(quiet),
        requires_health_check_(requires_health_check) {
    status_.pid = static_cast<int64_t>(getpid());
    status_.started_at = static_cast<int64_t>(std::time(nullptr));
    status_.state = "starting";
    status_.endpoint = std::move(endpoint);
    status_.version = DEFYX_CLI_VERSION;
  }

  bool Initialize(std::string* error) {
    std::lock_guard<std::mutex> lock(mutex_);
    return WriteStatusLocked(error);
  }

  uint64_t BeginAttempt() {
    std::unique_lock<std::mutex> lock(mutex_);
    ++attempt_generation_;
    core_connected_ = false;
    terminal_event_ = defyx_cli::ProgressEvent::none;
    status_.state = "connecting";
    std::string ignored;
    WriteStatusLocked(&ignored);
    const uint64_t generation = attempt_generation_;
    lock.unlock();
    condition_.notify_all();
    return generation;
  }

  void HandleProgress(const std::string& message, uint64_t generation) {
    const defyx_cli::ProgressEvent event =
        defyx_cli::ParseProgressEvent(message);

    std::unique_lock<std::mutex> lock(mutex_);
    if (!active_ || generation != attempt_generation_) {
      return;
    }
    if (!quiet_ || event != defyx_cli::ProgressEvent::none) {
      std::cout << message << std::endl;
    }

    switch (event) {
      case defyx_cli::ProgressEvent::connecting:
        status_.state = "connecting";
        break;
      case defyx_cli::ProgressEvent::connected:
        SetCoreConnectedLocked();
        break;
      case defyx_cli::ProgressEvent::failed:
        status_.state = "failed";
        terminal_event_ = event;
        break;
      case defyx_cli::ProgressEvent::stopped:
        status_.state = "stopped";
        terminal_event_ = event;
        break;
      case defyx_cli::ProgressEvent::none:
        return;
    }

    std::string ignored;
    WriteStatusLocked(&ignored);
    lock.unlock();
    condition_.notify_all();
  }

  void MarkCoreConnected(uint64_t generation) {
    std::unique_lock<std::mutex> lock(mutex_);
    if (!active_ || generation != attempt_generation_ ||
        terminal_event_ != defyx_cli::ProgressEvent::none) {
      return;
    }
    SetCoreConnectedLocked();
    std::string ignored;
    WriteStatusLocked(&ignored);
    lock.unlock();
    condition_.notify_all();
  }

  bool MarkHealthy(uint64_t generation) {
    std::unique_lock<std::mutex> lock(mutex_);
    if (!active_ || generation != attempt_generation_ ||
        terminal_event_ != defyx_cli::ProgressEvent::none) {
      return false;
    }
    SetConnectedLocked();
    std::string ignored;
    WriteStatusLocked(&ignored);
    lock.unlock();
    condition_.notify_all();
    return true;
  }

  void MarkStopping() {
    UpdateState("stopping", defyx_cli::ProgressEvent::none);
  }

  void Deactivate() {
    std::lock_guard<std::mutex> lock(mutex_);
    active_ = false;
  }

  bool connected() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return connected_;
  }

  bool core_connected(uint64_t generation) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return generation == attempt_generation_ && core_connected_;
  }

  defyx_cli::ProgressEvent terminal_event(uint64_t generation) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (generation != attempt_generation_) {
      return defyx_cli::ProgressEvent::none;
    }
    return terminal_event_;
  }

  void WaitForUpdate(std::chrono::milliseconds duration) {
    std::unique_lock<std::mutex> lock(mutex_);
    condition_.wait_for(lock, duration);
  }

 private:
  void SetCoreConnectedLocked() {
    core_connected_ = true;
    if (requires_health_check_) {
      status_.state = "checking";
    } else {
      SetConnectedLocked();
    }
  }

  void SetConnectedLocked() {
    status_.state = "connected";
    if (!connected_) {
      connected_ = true;
      std::cout << "Connected. SOCKS5 proxy: " << status_.endpoint << '\n'
                << "Example: curl --proxy " << status_.endpoint
                << " https://ifconfig.me" << std::endl;
    }
  }

  void UpdateState(const std::string& state,
                   defyx_cli::ProgressEvent terminal_event) {
    std::unique_lock<std::mutex> lock(mutex_);
    status_.state = state;
    if (terminal_event != defyx_cli::ProgressEvent::none) {
      terminal_event_ = terminal_event;
    }
    std::string ignored;
    WriteStatusLocked(&ignored);
    lock.unlock();
    condition_.notify_all();
  }

  bool WriteStatusLocked(std::string* error) const {
    return defyx_cli::WriteRuntimeStatus(cache_directory_, status_, error);
  }

  std::string cache_directory_;
  bool quiet_;
  bool requires_health_check_;
  mutable std::mutex mutex_;
  std::condition_variable condition_;
  defyx_cli::RuntimeStatus status_;
  defyx_cli::ProgressEvent terminal_event_ =
      defyx_cli::ProgressEvent::none;
  uint64_t attempt_generation_ = 0;
  bool core_connected_ = false;
  bool connected_ = false;
  bool active_ = true;
};

int ShowStatus(const defyx_cli::Options& options) {
  defyx_cli::RuntimeStatus status;
  std::string error;
  if (!defyx_cli::ReadRuntimeStatus(options.cache_directory, &status, &error)) {
    std::cout << "DefyxVPN CLI is not running." << std::endl;
    return kNotRunningExitCode;
  }

  if (!defyx_cli::ProcessExists(status.pid) ||
      !defyx_cli::IsDefyxCliProcess(status.pid)) {
    std::string ignored;
    defyx_cli::RemoveRuntimeStatus(options.cache_directory, &ignored);
    std::cout << "DefyxVPN CLI is not running (removed stale status)."
              << std::endl;
    return kNotRunningExitCode;
  }

  std::time_t started_at = static_cast<std::time_t>(status.started_at);
  std::tm local_time {};
  localtime_r(&started_at, &local_time);

  std::cout << "State:    " << status.state << '\n'
            << "PID:      " << status.pid << '\n'
            << "Endpoint: " << status.endpoint << '\n'
            << "Started:  " << std::put_time(&local_time, "%Y-%m-%d %H:%M:%S")
            << '\n'
            << "Version:  " << status.version << std::endl;
  return 0;
}

int Disconnect(const defyx_cli::Options& options) {
  defyx_cli::RuntimeStatus status;
  std::string error;
  if (!defyx_cli::ReadRuntimeStatus(options.cache_directory, &status, &error) ||
      !defyx_cli::ProcessExists(status.pid)) {
    std::cout << "DefyxVPN CLI is not running." << std::endl;
    return kNotRunningExitCode;
  }

  if (!defyx_cli::IsDefyxCliProcess(status.pid)) {
    std::cerr << "Refusing to signal PID " << status.pid
              << ": it is not a DefyxVPN CLI process." << std::endl;
    return kNotRunningExitCode;
  }

  if (kill(static_cast<pid_t>(status.pid), SIGTERM) != 0 && errno != ESRCH) {
    std::cerr << "Failed to stop PID " << status.pid << ": "
              << std::strerror(errno) << std::endl;
    return 2;
  }

  for (int attempt = 0; attempt < 50; ++attempt) {
    if (!defyx_cli::ProcessExists(status.pid)) {
      std::string ignored;
      defyx_cli::RemoveRuntimeStatus(options.cache_directory, &ignored);
      std::cout << "Disconnected." << std::endl;
      return 0;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }

  std::cerr << "Stop signal sent, but PID " << status.pid
            << " is still running." << std::endl;
  return 2;
}

int Connect(const defyx_cli::Options& options) {
  std::string error;
  defyx_cli::InstanceLock instance_lock;
  if (!instance_lock.Acquire(options.cache_directory, &error)) {
    std::cerr << "error: " << error << std::endl;
    return 2;
  }

  const uint16_t listen_port =
      static_cast<uint16_t>(options.listen_port);
  const bool uses_core_endpoint =
      options.listen_address == kCoreProxyAddress &&
      listen_port == kCoreProxyPort;
  if (!uses_core_endpoint && options.listen_address == "0.0.0.0" &&
      listen_port == kCoreProxyPort) {
    std::cerr
        << "error: 0.0.0.0:5000 conflicts with DXcore's internal "
           "127.0.0.1:5000 listener; choose another --listen-port"
        << std::endl;
    return 2;
  }

  defyx_cli::TcpForwarder forwarder;
  if (!uses_core_endpoint &&
      !forwarder.Start(options.listen_address, listen_port,
                       kCoreProxyAddress, kCoreProxyPort, &error)) {
    std::cerr << "error: " << error << std::endl;
    return 2;
  }

  const std::string proxy_endpoint =
      defyx_cli::FormatSocksEndpoint(options.listen_address, listen_port);
  if (!defyx_cli::IsLoopbackAddress(options.listen_address)) {
    std::cerr
        << "warning: exposing an unauthenticated SOCKS5 proxy on "
        << proxy_endpoint
        << "; restrict access with the host or network firewall"
        << std::endl;
  }

  RuntimeTracker tracker(options.cache_directory, options.quiet,
                         proxy_endpoint, options.health_check);
  if (!tracker.Initialize(&error)) {
    std::cerr << "error: " << error << std::endl;
    return 2;
  }

  const auto remove_status = [&options]() {
    std::string ignored;
    defyx_cli::RemoveRuntimeStatus(options.cache_directory, &ignored);
  };

  if (!defyx_core::LoadCoreDll(options.core_library)) {
    std::cerr << "error: could not load libdxcore_amd64.so";
    const std::string core_error = defyx_core::GetLastError();
    if (!core_error.empty()) {
      std::cerr << ": " << core_error;
    }
    std::cerr << std::endl;
    remove_status();
    return 2;
  }

  defyx_core::EnableVerboseLogs(options.verbose);
  defyx_core::RegisterProgressHandler(
      [&tracker](std::string message) {
        tracker.HandleProgress(message, 0);
      });
  defyx_core::SetCacheDir(options.cache_directory);
  defyx_core::SetTimeZone(LocalUtcOffsetHours());
  defyx_core::SetAsnName();

  const auto detach_progress = [&tracker]() {
    defyx_core::RegisterProgressHandler(nullptr);
    tracker.Deactivate();
  };

  const defyx_cli::FlowLineResult flowline = ResolveFlowLine(options);
  if (!flowline.ok()) {
    std::cerr << "error: unable to prepare a flowline: " << flowline.error
              << '\n'
              << "Provide an exported configuration with --flowline-file."
              << std::endl;
    detach_progress();
    remove_status();
    return 2;
  }

  const std::string pattern =
      options.pattern.empty() ? flowline.default_pattern : options.pattern;
  if (pattern.empty()) {
    std::cerr
        << "error: the flowline has no enabled labeled connection methods; "
           "provide --pattern explicitly"
        << std::endl;
    detach_progress();
    remove_status();
    return 2;
  }

  const std::vector<std::string> connection_methods =
      options.health_check
          ? defyx_cli::SplitConnectionMethods(pattern)
          : std::vector<std::string> {pattern};
  if (connection_methods.empty()) {
    std::cerr << "error: --pattern does not contain a connection method"
              << std::endl;
    detach_progress();
    remove_status();
    return 2;
  }

  if (!options.quiet) {
    std::cout << "Starting DefyxVPN in the foreground. Press Ctrl+C to stop."
              << '\n';
    if (options.pattern.empty()) {
      std::cout << "Using enabled connection methods: " << pattern << '\n';
    }
    std::cout << std::flush;
  }

  const auto connection_started = std::chrono::steady_clock::now();
  int result = 0;
  bool connection_ready = false;
  uint64_t active_generation = 0;

  const auto stop_attempt = []() {
    defyx_core::RegisterProgressHandler(nullptr);
    defyx_core::StopVPN();
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
  };

  for (size_t method_index = 0;
       method_index < connection_methods.size() &&
       g_shutdown_signal == 0;
       ++method_index) {
    const std::string& method = connection_methods[method_index];
    active_generation = tracker.BeginAttempt();
    defyx_core::RegisterProgressHandler(
        [&tracker, active_generation](std::string message) {
          tracker.HandleProgress(message, active_generation);
        });

    if (options.health_check) {
      std::cout << "Trying connection method: " << method << std::endl;
    }

    const bool request_accepted =
        defyx_core::StartVPN(options.cache_directory, flowline.value,
                             method, options.deep_scan,
                             options.health_check);
    bool attempt_failed = !request_accepted;
    bool timed_out = false;
    bool health_checker_failed = false;
    auto next_status_poll = std::chrono::steady_clock::now();

    if (!request_accepted) {
      std::cerr << (options.health_check ? "warning: " : "error: ")
                << "DXcore rejected "
                << (options.health_check ? method : "the connection request");
      const std::string core_error = defyx_core::GetLastError();
      if (!core_error.empty()) {
        std::cerr << ": " << core_error;
      }
      std::cerr << std::endl;
      if (!options.health_check) {
        result = 2;
      }
    }

    while (!attempt_failed && g_shutdown_signal == 0) {
      const defyx_cli::ProgressEvent terminal_event =
          tracker.terminal_event(active_generation);
      if (terminal_event == defyx_cli::ProgressEvent::failed ||
          terminal_event == defyx_cli::ProgressEvent::stopped) {
        std::cerr
            << (options.health_check ? "warning: " : "")
            << (terminal_event == defyx_cli::ProgressEvent::failed
                    ? "Connection failed"
                    : "DXcore stopped unexpectedly");
        if (options.health_check) {
          std::cerr << " for " << method;
        }
        std::cerr << "." << std::endl;
        attempt_failed = true;
        break;
      }

      const auto now = std::chrono::steady_clock::now();
      if (options.timeout_seconds > 0 &&
          now - connection_started >=
              std::chrono::seconds(options.timeout_seconds)) {
        std::cerr << "Connection timed out after "
                  << options.timeout_seconds << " seconds." << std::endl;
        result = kConnectionFailureExitCode;
        timed_out = true;
        break;
      }

      if (now >= next_status_poll) {
        if (defyx_core::GetVpnStatus() == "connected" &&
            !tracker.core_connected(active_generation)) {
          tracker.MarkCoreConnected(active_generation);
        }
        next_status_poll = now + std::chrono::seconds(2);
      }

      if (tracker.core_connected(active_generation)) {
        if (!options.health_check) {
          connection_ready = tracker.connected();
          break;
        }

        if (!options.quiet) {
          std::cout << "Checking HTTPS connectivity through " << method
                    << "..." << std::endl;
        }
        defyx_cli::HealthCheckSettings health_settings;
        health_settings.proxy_address = kCoreProxyAddress;
        health_settings.proxy_port = kCoreProxyPort;
        health_settings.url = options.health_check_url;
        health_settings.minimum_bytes =
            static_cast<uint64_t>(options.health_check_min_bytes);
        health_settings.timeout_seconds =
            options.health_check_timeout_seconds;
        const defyx_cli::HealthCheckResult health =
            defyx_cli::RunHttpsHealthCheck(health_settings);

        if (health.healthy) {
          if (!options.quiet) {
            std::cout << "Health check passed for " << method << ": HTTP "
                      << health.http_status << ", "
                      << health.downloaded_bytes << " bytes." << std::endl;
          }
          connection_ready =
              tracker.MarkHealthy(active_generation);
        } else {
          std::cerr << "warning: health check failed for " << method
                    << ": " << health.error;
          if (health.http_status != 0 ||
              health.downloaded_bytes != 0) {
            std::cerr << " (HTTP " << health.http_status << ", "
                      << health.downloaded_bytes << " bytes)";
          }
          std::cerr << std::endl;
          attempt_failed = true;
          health_checker_failed = health.exit_code < 0;
          if (health_checker_failed) {
            result = 2;
          }
        }
        break;
      }

      tracker.WaitForUpdate(std::chrono::milliseconds(250));
    }

    if (connection_ready || g_shutdown_signal != 0 ||
        timed_out || health_checker_failed || result == 2) {
      break;
    }

    const bool has_next_method =
        method_index + 1 < connection_methods.size();
    if (has_next_method) {
      stop_attempt();
      std::cerr << "Trying the next connection method." << std::endl;
      continue;
    }

    result = kConnectionFailureExitCode;
  }

  while (connection_ready && g_shutdown_signal == 0) {
    const defyx_cli::ProgressEvent terminal_event =
        tracker.terminal_event(active_generation);
    if (terminal_event == defyx_cli::ProgressEvent::failed ||
        terminal_event == defyx_cli::ProgressEvent::stopped) {
      std::cerr
          << (terminal_event == defyx_cli::ProgressEvent::failed
                  ? "Connection failed."
                  : "DXcore stopped unexpectedly.")
          << std::endl;
      result = kConnectionFailureExitCode;
      break;
    }
    tracker.WaitForUpdate(std::chrono::milliseconds(250));
  }

  tracker.MarkStopping();
  if (!options.quiet) {
    std::cout << "Stopping DefyxVPN..." << std::endl;
  }
  defyx_core::RegisterProgressHandler(nullptr);
  defyx_core::StopVPN();
  defyx_core::Stop();
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  detach_progress();
  forwarder.Stop();
  remove_status();

  if (g_shutdown_signal != 0 && !options.quiet) {
    std::cout << "Disconnected." << std::endl;
  }
  return result;
}

}  // namespace

int main(int argc, char* argv[]) {
  std::vector<std::string> arguments;
  arguments.reserve(argc > 1 ? static_cast<size_t>(argc - 1) : 0U);
  for (int index = 1; index < argc; ++index) {
    arguments.emplace_back(argv[index]);
  }

  const defyx_cli::ParseResult parsed =
      defyx_cli::ParseOptions(arguments, defyx_cli::OptionsFromEnvironment());
  if (!parsed.ok()) {
    std::cerr << "error: " << parsed.error << "\n\n"
              << defyx_cli::Usage();
    return 1;
  }

  switch (parsed.options.command) {
    case defyx_cli::Command::help:
      std::cout << defyx_cli::Usage();
      return 0;
    case defyx_cli::Command::version:
      std::cout << "defyxvpn-cli " << DEFYX_CLI_VERSION << std::endl;
      return 0;
    case defyx_cli::Command::status:
      return ShowStatus(parsed.options);
    case defyx_cli::Command::disconnect:
      return Disconnect(parsed.options);
    case defyx_cli::Command::connect:
      std::signal(SIGINT, HandleSignal);
      std::signal(SIGTERM, HandleSignal);
      return Connect(parsed.options);
  }
  return 1;
}
