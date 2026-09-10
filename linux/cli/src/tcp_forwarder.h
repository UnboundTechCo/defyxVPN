#pragma once

#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_set>

namespace defyx_cli {

class TcpForwarder {
 public:
  TcpForwarder() = default;
  ~TcpForwarder();

  TcpForwarder(const TcpForwarder&) = delete;
  TcpForwarder& operator=(const TcpForwarder&) = delete;

  bool Start(const std::string& listen_address, uint16_t listen_port,
             const std::string& target_address, uint16_t target_port,
             std::string* error);
  void Stop();

  bool running() const { return listen_socket_ >= 0; }
  uint16_t listen_port() const { return listen_port_; }

 private:
  void AcceptLoop(int listener);
  void ForwardConnection(int client_socket);
  int ConnectTarget() const;
  void TrackSocket(int socket);
  void CloseTrackedSocket(int socket);

  int listen_socket_ = -1;
  uint16_t listen_port_ = 0;
  std::string target_address_;
  uint16_t target_port_ = 0;
  std::atomic<bool> stopping_ {false};
  std::thread accept_thread_;
  std::mutex workers_mutex_;
  std::condition_variable workers_finished_;
  size_t active_workers_ = 0;
  std::mutex sockets_mutex_;
  std::unordered_set<int> active_sockets_;
};

bool IsIpAddress(const std::string& address);
bool IsLoopbackAddress(const std::string& address);
bool IsWildcardAddress(const std::string& address);
std::string FormatSocksEndpoint(const std::string& address, uint16_t port);

}  // namespace defyx_cli
