#include "health_check.h"

#include "tcp_forwarder.h"

#include <algorithm>
#include <cerrno>
#include <cctype>
#include <cstring>
#include <sstream>
#include <string>
#include <unordered_set>
#include <vector>

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char** environ;

namespace defyx_cli {

namespace {

std::string Trim(const std::string& value) {
  size_t first = 0;
  while (first < value.size() &&
         std::isspace(static_cast<unsigned char>(value[first]))) {
    ++first;
  }

  size_t last = value.size();
  while (last > first &&
         std::isspace(static_cast<unsigned char>(value[last - 1]))) {
    --last;
  }
  return value.substr(first, last - first);
}

bool ParseMetrics(const std::string& output, HealthCheckResult* result) {
  std::istringstream stream(output);
  unsigned long long downloaded_bytes = 0;
  if (!(stream >> result->http_status >> downloaded_bytes)) {
    return false;
  }
  result->downloaded_bytes =
      static_cast<uint64_t>(downloaded_bytes);
  return true;
}

}  // namespace

std::vector<std::string> SplitConnectionMethods(
    const std::string& pattern) {
  std::vector<std::string> methods;
  std::unordered_set<std::string> seen;
  size_t start = 0;

  while (start <= pattern.size()) {
    const size_t separator = pattern.find(',', start);
    const size_t length =
        separator == std::string::npos ? std::string::npos
                                       : separator - start;
    std::string method = Trim(pattern.substr(start, length));
    if (!method.empty() && seen.insert(method).second) {
      methods.push_back(std::move(method));
    }
    if (separator == std::string::npos) {
      break;
    }
    start = separator + 1;
  }
  return methods;
}

HealthCheckResult RunHttpsHealthCheck(
    const HealthCheckSettings& settings) {
  HealthCheckResult result;
  int output_pipe[2] {-1, -1};
  if (pipe(output_pipe) != 0) {
    result.error =
        "cannot create health-check output pipe: " +
        std::string(std::strerror(errno));
    return result;
  }

  posix_spawn_file_actions_t actions;
  int action_result = posix_spawn_file_actions_init(&actions);
  if (action_result != 0) {
    close(output_pipe[0]);
    close(output_pipe[1]);
    result.error =
        "cannot prepare health-check process: " +
        std::string(std::strerror(action_result));
    return result;
  }
  if (action_result == 0) {
    action_result = posix_spawn_file_actions_adddup2(
        &actions, output_pipe[1], STDOUT_FILENO);
  }
  if (action_result == 0) {
    action_result =
        posix_spawn_file_actions_addclose(&actions, output_pipe[0]);
  }
  if (action_result == 0) {
    action_result =
        posix_spawn_file_actions_addclose(&actions, output_pipe[1]);
  }
  if (action_result != 0) {
    posix_spawn_file_actions_destroy(&actions);
    close(output_pipe[0]);
    close(output_pipe[1]);
    result.error =
        "cannot prepare health-check process: " +
        std::string(std::strerror(action_result));
    return result;
  }

  const int connect_timeout =
      std::max(1, std::min(10, settings.timeout_seconds));
  std::vector<std::string> arguments {
      settings.curl_executable,
      "--disable",
      "--silent",
      "--show-error",
      "--location",
      "--fail",
      "--proto",
      "=https",
      "--proto-redir",
      "=https",
      "--connect-timeout",
      std::to_string(connect_timeout),
      "--max-time",
      std::to_string(settings.timeout_seconds),
      "--proxy",
      FormatSocksEndpoint(settings.proxy_address, settings.proxy_port),
      "--noproxy",
      "",
      "--output",
      "/dev/null",
      "--write-out",
      "%{http_code} %{size_download}\n",
      settings.url,
  };
  std::vector<char*> argv;
  argv.reserve(arguments.size() + 1);
  for (std::string& argument : arguments) {
    argv.push_back(argument.data());
  }
  argv.push_back(nullptr);

  pid_t child = -1;
  const int spawn_result =
      posix_spawnp(&child, settings.curl_executable.c_str(), &actions,
                   nullptr, argv.data(), environ);
  posix_spawn_file_actions_destroy(&actions);
  close(output_pipe[1]);

  if (spawn_result != 0) {
    close(output_pipe[0]);
    result.error =
        "cannot start curl for health check: " +
        std::string(std::strerror(spawn_result));
    return result;
  }

  std::string output;
  char buffer[256];
  while (output.size() < 4096) {
    const ssize_t count = read(output_pipe[0], buffer, sizeof(buffer));
    if (count > 0) {
      output.append(buffer, static_cast<size_t>(count));
      continue;
    }
    if (count < 0 && errno == EINTR) {
      continue;
    }
    break;
  }
  close(output_pipe[0]);

  int child_status = 0;
  while (waitpid(child, &child_status, 0) < 0) {
    if (errno == EINTR) {
      continue;
    }
    result.error =
        "cannot wait for curl health check: " +
        std::string(std::strerror(errno));
    return result;
  }

  const bool metrics_valid = ParseMetrics(output, &result);
  if (WIFEXITED(child_status)) {
    result.exit_code = WEXITSTATUS(child_status);
    if (result.exit_code != 0) {
      result.error =
          "curl exited with code " + std::to_string(result.exit_code);
      return result;
    }
  } else if (WIFSIGNALED(child_status)) {
    result.error =
        "curl was terminated by signal " +
        std::to_string(WTERMSIG(child_status));
    return result;
  } else {
    result.error = "curl did not exit normally";
    return result;
  }

  if (!metrics_valid) {
    result.error = "curl returned invalid health-check metrics";
    return result;
  }
  if (result.http_status < 200 || result.http_status >= 300) {
    result.error =
        "health endpoint returned HTTP " +
        std::to_string(result.http_status);
    return result;
  }
  if (result.downloaded_bytes < settings.minimum_bytes) {
    result.error =
        "downloaded " + std::to_string(result.downloaded_bytes) +
        " bytes, expected at least " +
        std::to_string(settings.minimum_bytes);
    return result;
  }

  result.healthy = true;
  return result;
}

}  // namespace defyx_cli
