#include "proxy_manager.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <thread>
#include <vector>

namespace proxy {

namespace {

std::mutex g_mutex;
std::atomic<uint64_t> g_proxy_seq{0};
std::atomic<uint64_t> g_proxy_done{0};

const char* kIgnoreHosts =
    "localhost,127.0.0.0/8,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12";

struct CommandResult {
  int exit_code = -1;
  std::string output;
};

CommandResult RunCommand(const std::string& command) {
  CommandResult result;
  FILE* pipe = popen(command.c_str(), "r");
  if (!pipe) {
    return result;
  }
  char buffer[256];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    result.output.append(buffer);
  }
  int status = pclose(pipe);
  if (status != -1 && WIFEXITED(status)) {
    result.exit_code = WEXITSTATUS(status);
  }
  return result;
}

bool CommandExists(const std::string& cmd) {
  return RunCommand("command -v " + cmd + " >/dev/null 2>&1").exit_code == 0;
}

std::string ShellQuote(const std::string& value) {
  std::string out = "'";
  for (char c : value) {
    if (c == '\'') {
      out += "'\\''";
    } else {
      out += c;
    }
  }
  out += "'";
  return out;
}

std::string Trim(const std::string& s) {
  size_t start = s.find_first_not_of(" \t");
  if (start == std::string::npos) return "";
  size_t end = s.find_last_not_of(" \t");
  return s.substr(start, end - start + 1);
}

std::string BuildGsettingsArray(const std::string& csv) {
  std::string out = "[";
  std::stringstream ss(csv);
  std::string item;
  bool first = true;
  while (std::getline(ss, item, ',')) {
    item = Trim(item);
    if (item.empty()) continue;
    if (!first) out += ", ";
    out += "'" + item + "'";
    first = false;
  }
  out += "]";
  return out;
}

void ApplyGsettings(bool enable, const std::string& host, int port) {
  if (!CommandExists("gsettings")) return;
  if (RunCommand("gsettings get org.gnome.system.proxy mode >/dev/null 2>&1").exit_code != 0) {
    return;
  }
  if (enable) {
    RunCommand("gsettings set org.gnome.system.proxy.socks host " + ShellQuote(host));
    RunCommand("gsettings set org.gnome.system.proxy.socks port " + std::to_string(port));
    RunCommand("gsettings set org.gnome.system.proxy.http host '' 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy.http port 0 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy.https host '' 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy.https port 0 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy.ftp host '' 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy.ftp port 0 2>/dev/null");
    RunCommand("gsettings set org.gnome.system.proxy ignore-hosts \"" +
               BuildGsettingsArray(kIgnoreHosts) + "\"");
    RunCommand("gsettings set org.gnome.system.proxy mode 'manual'");
  } else {
    RunCommand("gsettings set org.gnome.system.proxy mode 'none'");
  }
}

void ApplyKde(bool enable, const std::string& host, int port) {
  std::string kw;
  if (CommandExists("kwriteconfig6")) {
    kw = "kwriteconfig6";
  } else if (CommandExists("kwriteconfig5")) {
    kw = "kwriteconfig5";
  } else {
    return;
  }

  const std::string group = " --file kioslaverc --group 'Proxy Settings' --key ";
  if (enable) {
    std::string socks = ShellQuote("socks://" + host + " " + std::to_string(port));
    RunCommand(kw + group + "ProxyType 1");
    RunCommand(kw + group + "socksProxy " + socks);
    RunCommand(kw + group + "httpProxy " + socks);
    RunCommand(kw + group + "httpsProxy " + socks);
    RunCommand(kw + group + "NoProxyFor " + ShellQuote(kIgnoreHosts));
  } else {
    RunCommand(kw + group + "ProxyType 0");
  }
  if (CommandExists("dbus-send")) {
    RunCommand("dbus-send --type=signal /KIO/Scheduler "
               "org.kde.KIO.Scheduler.reparseSlaveConfiguration string:'' 2>/dev/null");
  }
}

void ApplyXfce(bool enable, const std::string& host, int port) {
  if (!CommandExists("xfconf-query")) return;
  if (RunCommand("xfconf-query -c xfce4-session -l >/dev/null 2>&1").exit_code != 0) {
    return;
  }
  const char* protos[] = {"Http", "Https", "Ftp"};
  for (const char* proto : protos) {
    std::string base = std::string("xfconf-query -c xfce4-session -p /general/Proxy") + proto;
    if (enable) {
      RunCommand(base + "Host -n -t string -s " + ShellQuote(host) + " 2>/dev/null || " +
                 base + "Host -s " + ShellQuote(host) + " 2>/dev/null");
      RunCommand(base + "Port -n -t int -s " + std::to_string(port) + " 2>/dev/null || " +
                 base + "Port -s " + std::to_string(port) + " 2>/dev/null");
    } else {
      RunCommand(base + "Host -r 2>/dev/null");
      RunCommand(base + "Port -r 2>/dev/null");
    }
  }
}

void ApplyEnv(bool enable, const std::string& host, int port) {
  std::string socks = ShellQuote("socks5://" + host + ":" + std::to_string(port));
  std::string ignore = ShellQuote(kIgnoreHosts);
  if (enable) {
    if (CommandExists("dbus-update-activation-environment")) {
      RunCommand("dbus-update-activation-environment --systemd all_proxy=" + socks +
                 " ALL_PROXY=" + socks + " no_proxy=" + ignore + " NO_PROXY=" + ignore +
                 " >/dev/null 2>&1");
    }
    if (CommandExists("systemctl")) {
      RunCommand("systemctl --user set-environment all_proxy=" + socks +
                 " ALL_PROXY=" + socks + " no_proxy=" + ignore + " NO_PROXY=" + ignore +
                 " >/dev/null 2>&1");
    }
  } else {
    if (CommandExists("dbus-update-activation-environment")) {
      RunCommand("dbus-update-activation-environment --systemd "
                 "all_proxy= ALL_PROXY= no_proxy= NO_PROXY= >/dev/null 2>&1");
    }
    if (CommandExists("systemctl")) {
      RunCommand("systemctl --user unset-environment "
                 "all_proxy ALL_PROXY no_proxy NO_PROXY >/dev/null 2>&1");
    }
  }
}

void ApplyFirefoxProfile(const std::filesystem::path& profile, bool enable,
                         const std::string& host, int port) {
  std::filesystem::path user_js = profile / "user.js";

  std::vector<std::string> kept;
  std::ifstream in(user_js);
  if (in) {
    std::string line;
    while (std::getline(in, line)) {
      if (line.find("network.proxy") == std::string::npos) {
        kept.push_back(line);
      }
    }
    in.close();
  }

  std::ofstream out(user_js, std::ios::trunc);
  if (!out) return;
  for (const auto& line : kept) {
    out << line << "\n";
  }
  if (enable) {
    out << "user_pref(\"network.proxy.type\", 1);\n";
    out << "user_pref(\"network.proxy.socks\", \"" << host << "\");\n";
    out << "user_pref(\"network.proxy.socks_port\", " << port << ");\n";
    out << "user_pref(\"network.proxy.socks_version\", 5);\n";
    out << "user_pref(\"network.proxy.socks_remote_dns\", true);\n";
  } else {
    out << "user_pref(\"network.proxy.type\", 0);\n";
  }
}

void ApplyFirefox(bool enable, const std::string& host, int port) {
  const char* home = std::getenv("HOME");
  if (!home) return;

  std::vector<std::filesystem::path> roots = {
      std::filesystem::path(home) / ".mozilla" / "firefox",
      std::filesystem::path(home) / "snap" / "firefox" / "common" / ".mozilla" / "firefox",
      std::filesystem::path(home) / ".var" / "app" / "org.mozilla.firefox" / ".mozilla" / "firefox",
  };

  std::error_code ec;
  for (const auto& root : roots) {
    if (!std::filesystem::is_directory(root, ec)) continue;
    for (const auto& entry : std::filesystem::directory_iterator(root, ec)) {
      if (!entry.is_directory(ec)) continue;
      const auto& dir = entry.path();
      if (std::filesystem::exists(dir / "prefs.js", ec) ||
          std::filesystem::exists(dir / "times.json", ec)) {
        ApplyFirefoxProfile(dir, enable, host, port);
      }
    }
  }
}

void ApplyProxy(uint64_t seq, bool enable, const std::string& host, int port) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (seq < g_proxy_done.load()) {
    return;
  }
  g_proxy_done.store(seq);
  ApplyGsettings(enable, host, port);
  ApplyKde(enable, host, port);
  ApplyXfce(enable, host, port);
  ApplyEnv(enable, host, port);
  ApplyFirefox(enable, host, port);
}

}  // namespace

bool ApplySystemProxy(const ProxyConfig& config) {
  if (config.host.empty() || config.port <= 0) {
    return false;
  }
  uint64_t seq = ++g_proxy_seq;
  ApplyProxy(seq, true, config.host, config.port);
  return true;
}

void ResetSystemProxy() {
  uint64_t seq = ++g_proxy_seq;
  ApplyProxy(seq, false, "127.0.0.1", 5000);
}

void ApplySystemProxyAsync(const ProxyConfig& config) {
  if (config.host.empty() || config.port <= 0) {
    return;
  }
  uint64_t seq = ++g_proxy_seq;
  std::string host = config.host;
  int port = config.port;
  std::thread([seq, host, port]() { ApplyProxy(seq, true, host, port); }).detach();
}

void ResetSystemProxyAsync() {
  uint64_t seq = ++g_proxy_seq;
  std::thread([seq]() { ApplyProxy(seq, false, "127.0.0.1", 5000); }).detach();
}

void RestorePendingSnapshot() {
  uint64_t seq = ++g_proxy_seq;
  ApplyProxy(seq, false, "127.0.0.1", 5000);
}

}  // namespace proxy
