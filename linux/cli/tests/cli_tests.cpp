#include "cli_options.h"
#include "flowline.h"
#include "health_check.h"
#include "progress.h"
#include "status_file.h"
#include "tcp_forwarder.h"

#include <atomic>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include <arpa/inet.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

namespace {

int g_failures = 0;
constexpr char kRelayMessage[] = "relay-check";

void Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << std::endl;
    ++g_failures;
  }
}

bool SendAllForTest(int socket, const char* data, size_t size) {
  size_t sent = 0;
  while (sent < size) {
    const ssize_t result =
        send(socket, data + sent, size - sent, MSG_NOSIGNAL);
    if (result > 0) {
      sent += static_cast<size_t>(result);
    } else if (result < 0 && errno == EINTR) {
      continue;
    } else {
      return false;
    }
  }
  return true;
}

bool ReceiveAllForTest(int socket, char* data, size_t size) {
  size_t received = 0;
  while (received < size) {
    const ssize_t result = recv(socket, data + received, size - received, 0);
    if (result > 0) {
      received += static_cast<size_t>(result);
    } else if (result < 0 && errno == EINTR) {
      continue;
    } else {
      return false;
    }
  }
  return true;
}

bool ReceiveEofForTest(int socket) {
  char data = '\0';
  while (true) {
    const ssize_t result = recv(socket, &data, sizeof(data), 0);
    if (result == 0) {
      return true;
    }
    if (result < 0 && errno == EINTR) {
      continue;
    }
    return false;
  }
}

void TestOptions() {
  defyx_cli::Options defaults;
  defaults.cache_directory = "/tmp/default";
  const defyx_cli::ParseResult result = defyx_cli::ParseOptions(
      {"connect", "--cache-dir", "/tmp/custom", "--pattern",
       "Warp,Psiphon", "--deep-scan", "--health-check", "--timeout", "45",
       "--health-check-url", "https://example.com/check",
       "--health-check-min-bytes", "4096", "--health-check-timeout", "12",
       "--health-check-interval", "30", "--health-check-failures", "3",
       "--quiet"},
      defaults);

  Check(result.ok(), "valid connect options should parse");
  Check(result.options.command == defyx_cli::Command::connect,
        "connect command should be selected");
  Check(result.options.cache_directory == "/tmp/custom",
        "cache directory should be parsed");
  Check(result.options.pattern == "Warp,Psiphon",
        "pattern should be parsed");
  Check(result.options.deep_scan, "deep scan should be enabled");
  Check(result.options.health_check, "health check should be enabled");
  Check(result.options.health_check_url == "https://example.com/check",
        "health-check URL should be parsed");
  Check(result.options.health_check_min_bytes == 4096,
        "health-check minimum size should be parsed");
  Check(result.options.health_check_timeout_seconds == 12,
        "health-check timeout should be parsed");
  Check(result.options.health_check_interval_seconds == 30,
        "health-check interval should be parsed");
  Check(result.options.health_check_failures == 3,
        "health-check failure threshold should be parsed");
  Check(result.options.timeout_seconds == 45, "timeout should be parsed");
  Check(result.options.quiet, "quiet should be enabled");

  const defyx_cli::ParseResult listener = defyx_cli::ParseOptions(
      {"connect", "--listen-address", "0.0.0.0", "--listen-port", "1080"},
      defaults);
  Check(listener.ok(), "custom listener options should parse");
  Check(listener.options.listen_address == "0.0.0.0",
        "listen address should be parsed");
  Check(listener.options.listen_port == 1080,
        "listen port should be parsed");

  const defyx_cli::ParseResult invalid =
      defyx_cli::ParseOptions({"connect", "--timeout", "-1"}, defaults);
  Check(!invalid.ok(), "negative timeout should be rejected");

  const defyx_cli::ParseResult invalid_address =
      defyx_cli::ParseOptions(
          {"connect", "--listen-address", "not-an-ip"}, defaults);
  Check(!invalid_address.ok(), "non-IP listen address should be rejected");

  const defyx_cli::ParseResult invalid_port =
      defyx_cli::ParseOptions(
          {"connect", "--listen-port", "65536"}, defaults);
  Check(!invalid_port.ok(), "out-of-range listen port should be rejected");

  const defyx_cli::ParseResult alias =
      defyx_cli::ParseOptions({"stop"}, defaults);
  Check(alias.ok() &&
            alias.options.command == defyx_cli::Command::disconnect,
        "stop alias should select disconnect");

  const defyx_cli::ParseResult invalid_health_url =
      defyx_cli::ParseOptions(
          {"connect", "--health-check-url", "http://example.com"}, defaults);
  Check(!invalid_health_url.ok(),
        "non-HTTPS health-check URL should be rejected");

  const defyx_cli::ParseResult invalid_health_timeout =
      defyx_cli::ParseOptions(
          {"connect", "--health-check-timeout", "0"}, defaults);
  Check(!invalid_health_timeout.ok(),
        "zero health-check timeout should be rejected");

  const defyx_cli::ParseResult disabled_runtime_health =
      defyx_cli::ParseOptions(
          {"connect", "--health-check-interval", "0"}, defaults);
  Check(disabled_runtime_health.ok() &&
            disabled_runtime_health.options.health_check_interval_seconds == 0,
        "zero runtime health-check interval should disable periodic checks");

  const defyx_cli::ParseResult invalid_health_interval =
      defyx_cli::ParseOptions(
          {"connect", "--health-check-interval", "-1"}, defaults);
  Check(!invalid_health_interval.ok(),
        "negative health-check interval should be rejected");

  const defyx_cli::ParseResult invalid_health_failures =
      defyx_cli::ParseOptions(
          {"connect", "--health-check-failures", "0"}, defaults);
  Check(!invalid_health_failures.ok(),
        "zero health-check failure threshold should be rejected");
}

void TestFlowLines() {
  const defyx_cli::FlowLineResult full = defyx_cli::NormalizeFlowLine(
      R"({"version":{},"flowLine":[{"label":"Hive","enabled":true},{"label":"Warp","enabled":false},{"label":"Outline","enabled":true}]})");
  Check(full.ok(), "full flowline response should normalize");
  Check(full.value ==
            R"([{"label":"Hive","enabled":true},{"label":"Warp","enabled":false},{"label":"Outline","enabled":true}])",
        "full response should select its flowLine array");
  Check(full.default_pattern == "Hive,Outline",
        "enabled labels should form the default pattern");

  const defyx_cli::FlowLineResult raw = defyx_cli::NormalizeFlowLine(
      R"({"startLine":0,"flowLine":[{"label":"Psiphon","enabled":true}]})");
  Check(raw.ok(), "raw flowline object should normalize");
  Check(raw.value ==
            R"({"startLine":0,"flowLine":[{"label":"Psiphon","enabled":true}]})",
        "raw flowline object should remain intact");
  Check(raw.default_pattern == "Psiphon",
        "raw object should expose its enabled label");

  const defyx_cli::FlowLineResult array =
      defyx_cli::NormalizeFlowLine(
          R"([{"label":"Outline","enabled":true}])");
  Check(array.ok() &&
            array.value == R"([{"label":"Outline","enabled":true}])",
        "raw flowline array should normalize");
  Check(array.default_pattern == "Outline",
        "raw array should expose its enabled label");

  const defyx_cli::FlowLineResult invalid =
      defyx_cli::NormalizeFlowLine("not-json");
  Check(!invalid.ok(), "invalid JSON should be rejected");
}

void TestProgressEvents() {
  Check(defyx_cli::ParseProgressEvent("Data: VPN connected") ==
            defyx_cli::ProgressEvent::connected,
        "connected progress should be recognized");
  Check(defyx_cli::ParseProgressEvent("Data: VPN connecting") ==
            defyx_cli::ProgressEvent::connecting,
        "connecting progress should be recognized");
  Check(defyx_cli::ParseProgressEvent("Data: VPN failed") ==
            defyx_cli::ProgressEvent::failed,
        "failed progress should be recognized");
  Check(defyx_cli::ParseProgressEvent("Data: VPN cancelled") ==
            defyx_cli::ProgressEvent::stopped,
        "cancelled progress should be recognized");
}

void TestHealthCheck() {
  const std::vector<std::string> methods =
      defyx_cli::SplitConnectionMethods(
          " Hive, Xray, Hive, ,Outline ");
  Check(methods ==
            std::vector<std::string>({"Hive", "Xray", "Outline"}),
        "connection methods should be trimmed and deduplicated");

  const std::filesystem::path directory =
      std::filesystem::temp_directory_path() /
      ("defyxvpn-health-test-" +
       std::to_string(static_cast<long long>(getpid())));
  std::error_code filesystem_error;
  std::filesystem::create_directories(directory, filesystem_error);
  const std::filesystem::path fake_curl = directory / "curl";

  {
    std::ofstream script(fake_curl);
    script << "#!/bin/sh\nprintf '200 65536\\n'\n";
  }
  chmod(fake_curl.c_str(), 0700);

  defyx_cli::HealthCheckSettings settings;
  settings.url = "https://example.com/check";
  settings.minimum_bytes = 65536;
  settings.timeout_seconds = 2;
  settings.curl_executable = fake_curl.string();

  const defyx_cli::HealthCheckResult healthy =
      defyx_cli::RunHttpsHealthCheck(settings);
  Check(healthy.healthy, "complete HTTPS transfer should pass health check");
  Check(healthy.http_status == 200,
        "health check should capture HTTP status");
  Check(healthy.downloaded_bytes == 65536,
        "health check should capture transfer size");

  {
    std::ofstream script(fake_curl, std::ios::trunc);
    script << "#!/bin/sh\nprintf '200 1024\\n'\nexit 18\n";
  }
  chmod(fake_curl.c_str(), 0700);

  const defyx_cli::HealthCheckResult truncated =
      defyx_cli::RunHttpsHealthCheck(settings);
  Check(!truncated.healthy,
        "truncated HTTPS transfer should fail health check");
  Check(truncated.exit_code == 18,
        "health check should preserve curl's partial-transfer exit code");
  Check(truncated.downloaded_bytes == 1024,
        "failed health check should preserve downloaded byte count");

  std::filesystem::remove_all(directory, filesystem_error);
}

void TestStatusRoundTrip() {
  const std::filesystem::path directory =
      std::filesystem::temp_directory_path() /
      ("defyxvpn-cli-test-" +
       std::to_string(static_cast<long long>(getpid())));

  defyx_cli::RuntimeStatus expected;
  expected.pid = static_cast<int64_t>(getpid());
  expected.started_at = 123456789;
  expected.state = "connected";
  expected.endpoint = "socks5h://127.0.0.1:5000";
  expected.version = "test";

  std::string error;
  Check(defyx_cli::WriteRuntimeStatus(directory.string(), expected, &error),
        "runtime status should be written: " + error);

  defyx_cli::RuntimeStatus actual;
  error.clear();
  Check(defyx_cli::ReadRuntimeStatus(directory.string(), &actual, &error),
        "runtime status should be read: " + error);
  Check(actual.pid == expected.pid, "status PID should round-trip");
  Check(actual.state == expected.state, "status state should round-trip");
  Check(actual.endpoint == expected.endpoint,
        "status endpoint should round-trip");

  error.clear();
  Check(defyx_cli::RemoveRuntimeStatus(directory.string(), &error),
        "runtime status should be removed: " + error);
  std::error_code ignored;
  std::filesystem::remove_all(directory, ignored);
}

void TestTcpForwarder() {
  Check(defyx_cli::IsLoopbackAddress("127.0.0.1"),
        "IPv4 loopback should be recognized");
  Check(defyx_cli::IsWildcardAddress("0.0.0.0"),
        "IPv4 wildcard should be recognized");
  Check(defyx_cli::FormatSocksEndpoint("::1", 1080) ==
            "socks5h://[::1]:1080",
        "IPv6 endpoint should use brackets");

  const int echo_listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (echo_listener < 0) {
    Check(false, "echo listener socket should be created");
    return;
  }

  sockaddr_in echo_address {};
  echo_address.sin_family = AF_INET;
  echo_address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  echo_address.sin_port = 0;
  if (bind(echo_listener,
           reinterpret_cast<const sockaddr*>(&echo_address),
           sizeof(echo_address)) != 0 ||
      listen(echo_listener, 1) != 0) {
    close(echo_listener);
    Check(false, "echo listener should bind");
    return;
  }

  socklen_t echo_length = sizeof(echo_address);
  if (getsockname(echo_listener,
                  reinterpret_cast<sockaddr*>(&echo_address),
                  &echo_length) != 0) {
    close(echo_listener);
    Check(false, "echo listener port should be available");
    return;
  }

  defyx_cli::TcpForwarder forwarder;
  std::string error;
  if (!forwarder.Start("127.0.0.1", 0, "127.0.0.1",
                       ntohs(echo_address.sin_port), &error)) {
    close(echo_listener);
    Check(false, "TCP forwarder should start: " + error);
    return;
  }

  std::atomic<bool> echo_ok {false};
  std::thread echo_thread([echo_listener, &echo_ok]() {
    pollfd pending {echo_listener, POLLIN, 0};
    if (poll(&pending, 1, 5000) <= 0) {
      close(echo_listener);
      return;
    }

    const int client = accept(echo_listener, nullptr, nullptr);
    if (client >= 0) {
      char buffer[sizeof(kRelayMessage)] {};
      if (ReceiveAllForTest(client, buffer, sizeof(buffer)) &&
          ReceiveEofForTest(client) &&
          SendAllForTest(client, kRelayMessage, sizeof(kRelayMessage))) {
        echo_ok.store(true);
      }
      close(client);
    }
    close(echo_listener);
  });

  const int client = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  bool relay_ok = client >= 0;
  timeval client_timeout {};
  client_timeout.tv_sec = 5;
  if (client >= 0) {
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &client_timeout,
               sizeof(client_timeout));
  }
  sockaddr_in forwarder_address {};
  forwarder_address.sin_family = AF_INET;
  forwarder_address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  forwarder_address.sin_port = htons(forwarder.listen_port());

  if (relay_ok &&
      connect(client, reinterpret_cast<const sockaddr*>(&forwarder_address),
              sizeof(forwarder_address)) != 0) {
    relay_ok = false;
  }

  if (relay_ok &&
      !SendAllForTest(client, kRelayMessage, sizeof(kRelayMessage))) {
    relay_ok = false;
  }
  if (relay_ok && shutdown(client, SHUT_WR) != 0) {
    relay_ok = false;
  }

  char response[sizeof(kRelayMessage)] {};
  if (relay_ok) {
    relay_ok = ReceiveAllForTest(client, response, sizeof(response)) &&
               std::memcmp(response, kRelayMessage,
                           sizeof(kRelayMessage)) == 0;
  }
  if (client >= 0) {
    close(client);
  }

  forwarder.Stop();
  echo_thread.join();
  Check(relay_ok && echo_ok.load(),
        "TCP forwarder should preserve responses after a half-close");
}

}  // namespace

int main() {
  TestOptions();
  TestFlowLines();
  TestProgressEvents();
  TestHealthCheck();
  TestStatusRoundTrip();
  TestTcpForwarder();

  if (g_failures != 0) {
    std::cerr << g_failures << " test(s) failed" << std::endl;
    return 1;
  }
  std::cout << "All CLI tests passed" << std::endl;
  return 0;
}
