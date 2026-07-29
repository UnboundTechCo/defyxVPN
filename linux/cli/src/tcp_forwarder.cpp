#include "tcp_forwarder.h"

#include <array>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <string>
#include <system_error>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

namespace defyx_cli {

namespace {

constexpr size_t kRelayBufferSize = 32U * 1024U;
constexpr size_t kMaximumConnections = 256U;

std::string SocketError(const std::string& operation) {
  return operation + ": " + std::strerror(errno);
}

bool MakeSocketAddress(const std::string& address, uint16_t port,
                       sockaddr_storage* storage, socklen_t* length,
                       int* family) {
  std::memset(storage, 0, sizeof(*storage));

  auto* ipv4 = reinterpret_cast<sockaddr_in*>(storage);
  if (inet_pton(AF_INET, address.c_str(), &ipv4->sin_addr) == 1) {
    ipv4->sin_family = AF_INET;
    ipv4->sin_port = htons(port);
    *length = sizeof(*ipv4);
    *family = AF_INET;
    return true;
  }

  auto* ipv6 = reinterpret_cast<sockaddr_in6*>(storage);
  if (inet_pton(AF_INET6, address.c_str(), &ipv6->sin6_addr) == 1) {
    ipv6->sin6_family = AF_INET6;
    ipv6->sin6_port = htons(port);
    *length = sizeof(*ipv6);
    *family = AF_INET6;
    return true;
  }
  return false;
}

void SetCloseOnExec(int socket) {
  const int flags = fcntl(socket, F_GETFD);
  if (flags >= 0) {
    fcntl(socket, F_SETFD, flags | FD_CLOEXEC);
  }
}

bool SendAll(int socket, const char* data, size_t size) {
  size_t sent = 0;
  while (sent < size) {
    const ssize_t result =
        send(socket, data + sent, size - sent, MSG_NOSIGNAL);
    if (result > 0) {
      sent += static_cast<size_t>(result);
      continue;
    }
    if (result < 0 && errno == EINTR) {
      continue;
    }
    return false;
  }
  return true;
}

}  // namespace

TcpForwarder::~TcpForwarder() {
  Stop();
}

bool TcpForwarder::Start(const std::string& listen_address,
                         uint16_t listen_port,
                         const std::string& target_address,
                         uint16_t target_port, std::string* error) {
  if (running()) {
    if (error != nullptr) {
      *error = "TCP forwarder is already running";
    }
    return false;
  }

  sockaddr_storage listen_storage {};
  socklen_t listen_length = 0;
  int listen_family = 0;
  if (!MakeSocketAddress(listen_address, listen_port, &listen_storage,
                         &listen_length, &listen_family)) {
    if (error != nullptr) {
      *error = "listen address must be a literal IPv4 or IPv6 address";
    }
    return false;
  }

  sockaddr_storage target_storage {};
  socklen_t target_length = 0;
  int target_family = 0;
  if (!MakeSocketAddress(target_address, target_port, &target_storage,
                         &target_length, &target_family)) {
    if (error != nullptr) {
      *error = "target address must be a literal IPv4 or IPv6 address";
    }
    return false;
  }

  const int listener = socket(listen_family, SOCK_STREAM, IPPROTO_TCP);
  if (listener < 0) {
    if (error != nullptr) {
      *error = SocketError("cannot create listener");
    }
    return false;
  }
  SetCloseOnExec(listener);

  int enabled = 1;
  setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
  if (listen_family == AF_INET6) {
    setsockopt(listener, IPPROTO_IPV6, IPV6_V6ONLY, &enabled, sizeof(enabled));
  }

  if (bind(listener, reinterpret_cast<const sockaddr*>(&listen_storage),
           listen_length) != 0) {
    if (error != nullptr) {
      *error = SocketError("cannot bind " +
                           FormatSocksEndpoint(listen_address, listen_port));
    }
    close(listener);
    return false;
  }
  if (listen(listener, SOMAXCONN) != 0) {
    if (error != nullptr) {
      *error = SocketError("cannot listen on " +
                           FormatSocksEndpoint(listen_address, listen_port));
    }
    close(listener);
    return false;
  }

  sockaddr_storage bound_storage {};
  socklen_t bound_length = sizeof(bound_storage);
  if (getsockname(listener, reinterpret_cast<sockaddr*>(&bound_storage),
                  &bound_length) != 0) {
    if (error != nullptr) {
      *error = SocketError("cannot inspect listener");
    }
    close(listener);
    return false;
  }

  if (bound_storage.ss_family == AF_INET) {
    const auto* ipv4 =
        reinterpret_cast<const sockaddr_in*>(&bound_storage);
    listen_port_ = ntohs(ipv4->sin_port);
  } else {
    const auto* ipv6 =
        reinterpret_cast<const sockaddr_in6*>(&bound_storage);
    listen_port_ = ntohs(ipv6->sin6_port);
  }

  target_address_ = target_address;
  target_port_ = target_port;
  stopping_.store(false);
  listen_socket_ = listener;
  try {
    accept_thread_ =
        std::thread([this, listener]() { AcceptLoop(listener); });
  } catch (const std::system_error& exception) {
    listen_socket_ = -1;
    close(listener);
    if (error != nullptr) {
      *error = "cannot start listener thread: " +
               std::string(exception.what());
    }
    return false;
  }
  return true;
}

void TcpForwarder::Stop() {
  stopping_.store(true);

  const int listener = listen_socket_;
  listen_socket_ = -1;
  if (listener >= 0) {
    shutdown(listener, SHUT_RDWR);
    close(listener);
  }
  if (accept_thread_.joinable()) {
    accept_thread_.join();
  }

  {
    std::lock_guard<std::mutex> lock(sockets_mutex_);
    for (const int socket : active_sockets_) {
      shutdown(socket, SHUT_RDWR);
    }
  }
  {
    std::unique_lock<std::mutex> lock(workers_mutex_);
    workers_finished_.wait(
        lock, [this]() { return active_workers_ == 0; });
  }

  {
    std::lock_guard<std::mutex> lock(sockets_mutex_);
    active_sockets_.clear();
  }
  listen_port_ = 0;
  target_address_.clear();
  target_port_ = 0;
}

void TcpForwarder::AcceptLoop(int listener) {
  while (!stopping_.load()) {
    const int client = accept(listener, nullptr, nullptr);
    if (client < 0) {
      if (errno == EINTR) {
        continue;
      }
      if (stopping_.load() || errno == EBADF || errno == EINVAL) {
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      continue;
    }
    SetCloseOnExec(client);
    if (stopping_.load()) {
      close(client);
      break;
    }

    TrackSocket(client);
    bool at_capacity = false;
    {
      std::lock_guard<std::mutex> lock(workers_mutex_);
      if (active_workers_ >= kMaximumConnections) {
        at_capacity = true;
      } else {
        ++active_workers_;
      }
    }
    if (at_capacity) {
      CloseTrackedSocket(client);
      continue;
    }
    try {
      std::thread([this, client]() {
        ForwardConnection(client);
        {
          std::lock_guard<std::mutex> lock(workers_mutex_);
          --active_workers_;
        }
        workers_finished_.notify_all();
      }).detach();
    } catch (const std::system_error&) {
      {
        std::lock_guard<std::mutex> lock(workers_mutex_);
        --active_workers_;
      }
      CloseTrackedSocket(client);
      workers_finished_.notify_all();
    }
  }
}

void TcpForwarder::ForwardConnection(int client_socket) {
  const int target_socket = ConnectTarget();
  if (target_socket < 0) {
    CloseTrackedSocket(client_socket);
    return;
  }
  TrackSocket(target_socket);

  std::array<char, kRelayBufferSize> buffer {};
  pollfd sockets[2] = {
      {client_socket, POLLIN, 0},
      {target_socket, POLLIN, 0},
  };

  while (!stopping_.load()) {
    const int result = poll(sockets, 2, 500);
    if (result < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (result == 0) {
      continue;
    }

    bool relay_failed = false;
    for (size_t index = 0; index < 2; ++index) {
      const short events = sockets[index].revents;
      if ((events & POLLIN) != 0) {
        const ssize_t received =
            recv(sockets[index].fd, buffer.data(), buffer.size(), 0);
        const int destination = sockets[1U - index].fd;
        if (received <= 0 ||
            !SendAll(destination, buffer.data(),
                     static_cast<size_t>(received))) {
          relay_failed = true;
          break;
        }
      }
      if ((events & (POLLERR | POLLHUP | POLLNVAL)) != 0 &&
          (events & POLLIN) == 0) {
        relay_failed = true;
        break;
      }
    }
    if (relay_failed) {
      break;
    }
  }

  CloseTrackedSocket(target_socket);
  CloseTrackedSocket(client_socket);
}

int TcpForwarder::ConnectTarget() const {
  sockaddr_storage storage {};
  socklen_t length = 0;
  int family = 0;
  if (!MakeSocketAddress(target_address_, target_port_, &storage, &length,
                         &family)) {
    return -1;
  }

  const int target = socket(family, SOCK_STREAM, IPPROTO_TCP);
  if (target < 0) {
    return -1;
  }
  SetCloseOnExec(target);
  if (connect(target, reinterpret_cast<const sockaddr*>(&storage), length) !=
      0) {
    close(target);
    return -1;
  }
  return target;
}

void TcpForwarder::TrackSocket(int socket) {
  std::lock_guard<std::mutex> lock(sockets_mutex_);
  active_sockets_.insert(socket);
}

void TcpForwarder::CloseTrackedSocket(int socket) {
  {
    std::lock_guard<std::mutex> lock(sockets_mutex_);
    active_sockets_.erase(socket);
  }
  shutdown(socket, SHUT_RDWR);
  close(socket);
}

bool IsIpAddress(const std::string& address) {
  sockaddr_storage storage {};
  socklen_t length = 0;
  int family = 0;
  return MakeSocketAddress(address, 1, &storage, &length, &family);
}

bool IsLoopbackAddress(const std::string& address) {
  in_addr ipv4 {};
  if (inet_pton(AF_INET, address.c_str(), &ipv4) == 1) {
    return (ntohl(ipv4.s_addr) >> 24U) == 127U;
  }

  in6_addr ipv6 {};
  return inet_pton(AF_INET6, address.c_str(), &ipv6) == 1 &&
         IN6_IS_ADDR_LOOPBACK(&ipv6);
}

bool IsWildcardAddress(const std::string& address) {
  in_addr ipv4 {};
  if (inet_pton(AF_INET, address.c_str(), &ipv4) == 1) {
    return ipv4.s_addr == htonl(INADDR_ANY);
  }

  in6_addr ipv6 {};
  return inet_pton(AF_INET6, address.c_str(), &ipv6) == 1 &&
         IN6_IS_ADDR_UNSPECIFIED(&ipv6);
}

std::string FormatSocksEndpoint(const std::string& address, uint16_t port) {
  const bool is_ipv6 = address.find(':') != std::string::npos;
  return "socks5h://" + (is_ipv6 ? "[" + address + "]" : address) + ":" +
         std::to_string(port);
}

}  // namespace defyx_cli
