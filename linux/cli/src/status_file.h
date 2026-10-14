#pragma once

#include <cstdint>
#include <string>

namespace defyx_cli {

struct RuntimeStatus {
  int64_t pid = 0;
  int64_t started_at = 0;
  std::string state;
  std::string endpoint;
  std::string version;
};

class InstanceLock {
 public:
  InstanceLock() = default;
  ~InstanceLock();

  InstanceLock(const InstanceLock&) = delete;
  InstanceLock& operator=(const InstanceLock&) = delete;

  bool Acquire(const std::string& cache_directory, std::string* error);
  bool acquired() const { return file_descriptor_ >= 0; }

 private:
  int file_descriptor_ = -1;
};

std::string StatusFilePath(const std::string& cache_directory);
bool EnsurePrivateDirectory(const std::string& directory, std::string* error);
bool WriteRuntimeStatus(const std::string& cache_directory,
                        const RuntimeStatus& status, std::string* error);
bool ReadRuntimeStatus(const std::string& cache_directory,
                       RuntimeStatus* status, std::string* error);
bool RemoveRuntimeStatus(const std::string& cache_directory,
                         std::string* error);
bool ProcessExists(int64_t pid);
bool IsDefyxCliProcess(int64_t pid);

}  // namespace defyx_cli
