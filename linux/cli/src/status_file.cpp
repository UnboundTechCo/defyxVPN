#include "status_file.h"

#include <json-c/json.h>

#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <memory>
#include <string>

#include <fcntl.h>
#include <signal.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

namespace defyx_cli {

namespace {

constexpr const char* kStatusFileName = "defyxvpn-cli.status.json";
constexpr const char* kLockFileName = "defyxvpn-cli.lock";

using JsonPointer = std::unique_ptr<json_object, decltype(&json_object_put)>;
using TokenerPointer =
    std::unique_ptr<json_tokener, decltype(&json_tokener_free)>;

std::string ErrnoMessage(const std::string& operation) {
  return operation + ": " + std::strerror(errno);
}

bool ReadInt64(json_object* root, const char* key, int64_t* value) {
  json_object* field = nullptr;
  if (!json_object_object_get_ex(root, key, &field) ||
      json_object_get_type(field) != json_type_int) {
    return false;
  }
  *value = json_object_get_int64(field);
  return true;
}

bool ReadString(json_object* root, const char* key, std::string* value) {
  json_object* field = nullptr;
  if (!json_object_object_get_ex(root, key, &field) ||
      json_object_get_type(field) != json_type_string) {
    return false;
  }
  *value = json_object_get_string(field);
  return true;
}

}  // namespace

InstanceLock::~InstanceLock() {
  if (file_descriptor_ >= 0) {
    flock(file_descriptor_, LOCK_UN);
    close(file_descriptor_);
  }
}

bool InstanceLock::Acquire(const std::string& cache_directory,
                           std::string* error) {
  if (file_descriptor_ >= 0) {
    return true;
  }
  if (!EnsurePrivateDirectory(cache_directory, error)) {
    return false;
  }

  const std::filesystem::path path =
      std::filesystem::path(cache_directory) / kLockFileName;
  file_descriptor_ =
      open(path.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR);
  if (file_descriptor_ < 0) {
    if (error != nullptr) {
      *error = ErrnoMessage("cannot open " + path.string());
    }
    return false;
  }

  if (flock(file_descriptor_, LOCK_EX | LOCK_NB) != 0) {
    if (error != nullptr) {
      *error = errno == EWOULDBLOCK
                   ? "another DefyxVPN CLI instance is already running"
                   : ErrnoMessage("cannot lock " + path.string());
    }
    close(file_descriptor_);
    file_descriptor_ = -1;
    return false;
  }
  return true;
}

std::string StatusFilePath(const std::string& cache_directory) {
  return (std::filesystem::path(cache_directory) / kStatusFileName).string();
}

bool EnsurePrivateDirectory(const std::string& directory, std::string* error) {
  std::error_code filesystem_error;
  std::filesystem::create_directories(directory, filesystem_error);
  if (filesystem_error) {
    if (error != nullptr) {
      *error = "cannot create " + directory + ": " + filesystem_error.message();
    }
    return false;
  }
  if (!std::filesystem::is_directory(directory, filesystem_error)) {
    if (error != nullptr) {
      *error = directory + " is not a directory";
    }
    return false;
  }
  if (chmod(directory.c_str(), S_IRWXU) != 0) {
    if (error != nullptr) {
      *error = ErrnoMessage("cannot set permissions on " + directory);
    }
    return false;
  }
  return true;
}

bool WriteRuntimeStatus(const std::string& cache_directory,
                        const RuntimeStatus& status, std::string* error) {
  if (!EnsurePrivateDirectory(cache_directory, error)) {
    return false;
  }

  JsonPointer root(json_object_new_object(), &json_object_put);
  json_object_object_add(root.get(), "pid", json_object_new_int64(status.pid));
  json_object_object_add(root.get(), "startedAt",
                         json_object_new_int64(status.started_at));
  json_object_object_add(root.get(), "state",
                         json_object_new_string(status.state.c_str()));
  json_object_object_add(root.get(), "endpoint",
                         json_object_new_string(status.endpoint.c_str()));
  json_object_object_add(root.get(), "version",
                         json_object_new_string(status.version.c_str()));

  const std::filesystem::path target = StatusFilePath(cache_directory);
  const std::filesystem::path temporary =
      target.string() + ".tmp." + std::to_string(static_cast<long long>(getpid()));

  {
    std::ofstream stream(temporary, std::ios::out | std::ios::trunc);
    if (!stream) {
      if (error != nullptr) {
        *error = "cannot write " + temporary.string();
      }
      return false;
    }
    stream << json_object_to_json_string_ext(root.get(), JSON_C_TO_STRING_PLAIN)
           << '\n';
    if (!stream) {
      if (error != nullptr) {
        *error = "cannot finish writing " + temporary.string();
      }
      return false;
    }
  }

  if (chmod(temporary.c_str(), S_IRUSR | S_IWUSR) != 0) {
    if (error != nullptr) {
      *error = ErrnoMessage("cannot set permissions on " + temporary.string());
    }
    std::error_code ignored;
    std::filesystem::remove(temporary, ignored);
    return false;
  }

  std::error_code filesystem_error;
  std::filesystem::rename(temporary, target, filesystem_error);
  if (filesystem_error) {
    if (error != nullptr) {
      *error = "cannot replace " + target.string() + ": " +
               filesystem_error.message();
    }
    std::error_code ignored;
    std::filesystem::remove(temporary, ignored);
    return false;
  }
  return true;
}

bool ReadRuntimeStatus(const std::string& cache_directory,
                       RuntimeStatus* status, std::string* error) {
  if (status == nullptr) {
    if (error != nullptr) {
      *error = "status output is null";
    }
    return false;
  }

  const std::string path = StatusFilePath(cache_directory);
  std::ifstream stream(path);
  if (!stream) {
    if (error != nullptr) {
      *error = "no runtime status at " + path;
    }
    return false;
  }

  std::string payload((std::istreambuf_iterator<char>(stream)),
                      std::istreambuf_iterator<char>());
  TokenerPointer tokener(json_tokener_new(), &json_tokener_free);
  json_tokener_set_flags(tokener.get(), JSON_TOKENER_STRICT);
  JsonPointer root(
      json_tokener_parse_ex(tokener.get(), payload.data(),
                            static_cast<int>(payload.size())),
      &json_object_put);
  const json_tokener_error parse_error =
      json_tokener_get_error(tokener.get());
  if (!root || parse_error != json_tokener_success ||
      json_object_get_type(root.get()) != json_type_object) {
    if (error != nullptr) {
      *error = "invalid runtime status in " + path;
    }
    return false;
  }

  RuntimeStatus parsed;
  if (!ReadInt64(root.get(), "pid", &parsed.pid) ||
      !ReadInt64(root.get(), "startedAt", &parsed.started_at) ||
      !ReadString(root.get(), "state", &parsed.state) ||
      !ReadString(root.get(), "endpoint", &parsed.endpoint) ||
      !ReadString(root.get(), "version", &parsed.version) ||
      parsed.pid <= 0) {
    if (error != nullptr) {
      *error = "runtime status is missing required fields";
    }
    return false;
  }

  *status = parsed;
  return true;
}

bool RemoveRuntimeStatus(const std::string& cache_directory,
                         std::string* error) {
  const std::string path = StatusFilePath(cache_directory);
  std::error_code filesystem_error;
  const bool removed = std::filesystem::remove(path, filesystem_error);
  if (filesystem_error) {
    if (error != nullptr) {
      *error = filesystem_error.message();
    }
    return false;
  }

  const bool exists = std::filesystem::exists(path, filesystem_error);
  if (filesystem_error) {
    if (error != nullptr) {
      *error = filesystem_error.message();
    }
    return false;
  }
  return removed || !exists;
}

bool ProcessExists(int64_t pid) {
  if (pid <= 0) {
    return false;
  }
  if (kill(static_cast<pid_t>(pid), 0) == 0) {
    return true;
  }
  return errno == EPERM;
}

bool IsDefyxCliProcess(int64_t pid) {
  if (!ProcessExists(pid)) {
    return false;
  }

  const auto executable_path = [](int64_t process_id) {
    const std::string proc_path =
        "/proc/" + std::to_string(static_cast<long long>(process_id)) + "/exe";
    char executable[4096];
    const ssize_t length =
        readlink(proc_path.c_str(), executable, sizeof(executable) - 1);
    if (length <= 0) {
      return std::string();
    }
    executable[length] = '\0';
    return std::string(executable);
  };

  const std::string executable = executable_path(pid);
  if (executable.empty()) {
    return false;
  }

  const std::string current_executable =
      executable_path(static_cast<int64_t>(getpid()));
  if (!current_executable.empty() && executable == current_executable) {
    return true;
  }

  const std::string name = std::filesystem::path(executable).filename().string();
  return name == "defyxvpn-cli" ||
         name.rfind("defyxvpn-cli-", 0) == 0;
}

}  // namespace defyx_cli
