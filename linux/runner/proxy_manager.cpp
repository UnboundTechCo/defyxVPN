#include "proxy_manager.h"

#include "defyx_core.h"

#include <algorithm>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <vector>
// This is customized system proxy manager written by voidreaper. the code set proxy for different linux distro based in De-manager.it supports gnome,xfce,kde... 
// the QA for the gnome has been tested and fully in production level . for other distros please check and inform me. 
// This  code is in beta mode and i may replace it with library candidate.
namespace proxy {

namespace {

struct EnvSnapshot {
  bool captured = false;
  std::string http;
  std::string https;
  std::string ftp;
  std::string all;
  std::string no_proxy;
};

struct GsettingsSnapshot {
  std::string schema;
  bool captured = false;
  std::string mode;
  std::string http_host;
  std::string http_port;
  std::string https_host;
  std::string https_port;
  std::string socks_host;
  std::string socks_port;
  std::string ignore_hosts;
  std::string use_same_proxy;
  std::string http_enabled;
  std::string https_enabled;
  std::string socks_enabled;
  std::string ftp_host;
  std::string ftp_port;
  std::string ftp_enabled;
  bool supports_use_same_proxy = false;
  bool supports_http_enabled = false;
  bool supports_https_enabled = false;
  bool supports_socks_enabled = false;
  bool supports_ftp = false;
  bool supports_ftp_enabled = false;
  bool supports_ignore_hosts = false;
};

struct KdeSnapshot {
  bool captured = false;
  std::string proxy_type;
  std::string http_proxy;
  std::string https_proxy;
  std::string socks_proxy;
  std::string ftp_proxy;
  std::string no_proxy_for;
};

struct XfceSnapshot {
  bool captured = false;
  std::string channel;
  bool has_mode = false;
  std::string mode;
  bool has_use_same = false;
  std::string use_same;
  bool has_http_host = false;
  std::string http_host;
  bool has_http_port = false;
  std::string http_port;
  bool has_https_host = false;
  std::string https_host;
  bool has_https_port = false;
  std::string https_port;
  bool has_socks_host = false;
  std::string socks_host;
  bool has_socks_port = false;
  std::string socks_port;
  bool has_ftp_host = false;
  std::string ftp_host;
  bool has_ftp_port = false;
  std::string ftp_port;
  bool has_ignore_hosts = false;
  std::vector<std::string> ignore_hosts;
};

struct NmConnectionSnapshot {
  std::string name;
  std::string method;
  std::string http;
  std::string https;
  std::string socks;
  bool manual_supported = false;
};

struct NmSnapshot {
  bool captured = false;
  std::vector<NmConnectionSnapshot> connections;
};

struct Snapshot {
  EnvSnapshot env;
  std::vector<GsettingsSnapshot> gsettings;
  KdeSnapshot kde;
  XfceSnapshot xfce;
  NmSnapshot nm;
};

struct ProxyBackends {
  bool use_env = true;
  bool use_gsettings = false;
  bool use_kde = false;
  bool use_xfconf = false;
  bool use_nm = false;
};

struct ApplyResults {
  bool env_applied = false;
  bool gsettings_applied = false;
  bool kde_applied = false;
  bool xfce_applied = false;
  bool nm_applied = false;
};

constexpr int kSnapshotVersion = 3;

std::mutex g_mutex;
Snapshot g_snapshot;
bool g_applied = false;
std::string g_snapshot_path;

struct CommandResult {
  int exit_code = -1;
  std::string output;
};

CommandResult RunCommandInternal(const std::string& command, bool log_on_error) {
  CommandResult result;
  FILE* pipe = popen(command.c_str(), "r");
  if (!pipe) {
    defyx_core::LogMessage("ProxyManager: failed to run command: " + command);
    return result;
  }

  char buffer[256];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    result.output.append(buffer);
  }

  int status = pclose(pipe);
  if (status == -1) {
    defyx_core::LogMessage("ProxyManager: failed to close command pipe");
    result.exit_code = -1;
    return result;
  }
  if (WIFEXITED(status)) {
    result.exit_code = WEXITSTATUS(status);
  } else {
    result.exit_code = status;
  }
  if (result.exit_code != 0 && log_on_error) {
    std::ostringstream oss;
    oss << "ProxyManager: command exited with code " << result.exit_code << ": " << command;
    defyx_core::LogMessage(oss.str());
  }
  return result;
}

CommandResult RunCommand(const std::string& command) {
  return RunCommandInternal(command, true);
}

CommandResult RunCommandQuiet(const std::string& command) {
  return RunCommandInternal(command, false);
}

bool CommandExists(const std::string& cmd) {
  CommandResult r = RunCommandQuiet("which " + cmd + " 2>/dev/null");
  return r.exit_code == 0 && !r.output.empty();
}

bool GSettingsKeyExists(const std::string& schema, const std::string& key) {
  if (!CommandExists("gsettings")) return false;
  std::string range_cmd = "gsettings range " + schema + " " + key + " >/dev/null 2>&1";
  CommandResult range_result = RunCommandQuiet(range_cmd);
  if (range_result.exit_code == 0) {
    return true;
  }
  std::string get_cmd = "gsettings get " + schema + " " + key + " >/dev/null 2>&1";
  CommandResult get_result = RunCommandQuiet(get_cmd);
  return get_result.exit_code == 0;
}

std::string Escape(const std::string& value) {
  std::string escaped;
  escaped.reserve(value.size());
  for (size_t i = 0; i < value.size(); ++i) {
    char c = value[i];
    if (c == '\\' || c == '\n' || c == '\r') {
      escaped.push_back('\\');
      if (c == '\\') escaped.push_back('\\');
      if (c == '\n') escaped.push_back('n');
      if (c == '\r') escaped.push_back('r');
    } else {
      escaped.push_back(c);
    }
  }
  return escaped;
}

std::string Unescape(const std::string& value) {
  std::string unescaped;
  unescaped.reserve(value.size());
  for (size_t i = 0; i < value.size(); ++i) {
    char c = value[i];
    if (c == '\\' && i + 1 < value.size()) {
      char next = value[i + 1];
      if (next == '\\') {
        unescaped.push_back('\\');
        ++i;
        continue;
      }
      if (next == 'n') {
        unescaped.push_back('\n');
        ++i;
        continue;
      }
      if (next == 'r') {
        unescaped.push_back('\r');
        ++i;
        continue;
      }
    }
    unescaped.push_back(c);
  }
  return unescaped;
}

std::string TrimWhitespace(const std::string& input) {
  if (input.empty()) return input;
  size_t start = 0;
  size_t end = input.size();
  while (start < end && std::isspace(static_cast<unsigned char>(input[start]))) {
    ++start;
  }
  while (end > start && std::isspace(static_cast<unsigned char>(input[end - 1]))) {
    --end;
  }
  return input.substr(start, end - start);
}

std::string MakeSubSchema(const std::string& schema, const std::string& group) {
  return schema + "." + group;
}

std::string ToUpper(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::toupper(c));
  });
  return value;
}

std::string CurrentDesktopString() {
  const char* desktop = std::getenv("XDG_CURRENT_DESKTOP");
  if (desktop && *desktop) {
    return desktop;
  }
  const char* session = std::getenv("DESKTOP_SESSION");
  if (session && *session) {
    return session;
  }
  return "unknown";
}

std::vector<std::string> TokenizeDesktopString(const std::string& value) {
  std::vector<std::string> tokens;
  std::string current;
  auto flush_current = [&]() {
    if (current.empty()) return;
    std::string upper = ToUpper(current);
    if (std::find(tokens.begin(), tokens.end(), upper) == tokens.end()) {
      tokens.push_back(upper);
    }
    current.clear();
  };

  for (char ch : value) {
    if (ch == ':' || ch == ';' || ch == ',' || std::isspace(static_cast<unsigned char>(ch))) {
      flush_current();
      continue;
    }
    current.push_back(ch);
  }
  flush_current();
  return tokens;
}

std::vector<std::string> DesktopTokens() {
  std::vector<std::string> tokens;
  auto append_tokens = [&](const char* raw) {
    if (!raw || !*raw) return;
    auto parts = TokenizeDesktopString(raw);
    for (const auto& part : parts) {
      if (std::find(tokens.begin(), tokens.end(), part) == tokens.end()) {
        tokens.push_back(part);
      }
    }
  };

  append_tokens(std::getenv("XDG_CURRENT_DESKTOP"));
  append_tokens(std::getenv("DESKTOP_SESSION"));
  append_tokens(std::getenv("GDMSESSION"));
  append_tokens(std::getenv("XDG_SESSION_DESKTOP"));

  if (tokens.empty()) {
    std::string fallback = CurrentDesktopString();
    if (!fallback.empty() && fallback != "unknown") {
      append_tokens(fallback.c_str());
    }
  }

  return tokens;
}

std::string JoinStrings(const std::vector<std::string>& items, const std::string& delimiter) {
  if (items.empty()) return "";
  std::ostringstream oss;
  for (size_t i = 0; i < items.size(); ++i) {
    if (i > 0) oss << delimiter;
    oss << items[i];
  }
  return oss.str();
}

std::string JoinStrings(const std::vector<std::string>& items, char delimiter) {
  std::ostringstream oss;
  for (size_t i = 0; i < items.size(); ++i) {
    if (i > 0) oss << delimiter;
    oss << items[i];
  }
  return oss.str();
}

// Forward declaration for helpers that require shell quoting but are defined later.
std::string QuoteForShell(const std::string& value);

std::vector<std::string> SplitString(const std::string& input, char delimiter) {
  std::vector<std::string> parts;
  std::stringstream ss(input);
  std::string item;
  while (std::getline(ss, item, delimiter)) {
    std::string trimmed = TrimWhitespace(item);
    if (!trimmed.empty()) {
      parts.push_back(trimmed);
    }
  }
  return parts;
}

std::vector<std::string> ParseXfconfList(const std::string& input) {
  std::vector<std::string> values;
  std::stringstream ss(input);
  std::string line;
  while (std::getline(ss, line)) {
    std::string trimmed = TrimWhitespace(line);
    if (!trimmed.empty()) {
      values.push_back(trimmed);
    }
  }
  return values;
}

std::vector<std::string> BuildNoProxyList(const std::string& extra) {
  std::vector<std::string> defaults = {"localhost", "127.0.0.1", "::1"};
  std::vector<std::string> extra_parts = SplitString(extra, ',');
  for (const auto& entry : extra_parts) {
    if (std::find(defaults.begin(), defaults.end(), entry) == defaults.end()) {
      defaults.push_back(entry);
    }
  }
  return defaults;
}

bool NormalizeGsettingsValueForSet(const std::string& raw, std::string* out) {
  if (!out) return false;
  std::string trimmed = raw;
  while (!trimmed.empty() && (trimmed.back() == '\n' || trimmed.back() == '\r')) {
    trimmed.pop_back();
  }
  trimmed = TrimWhitespace(trimmed);
  if (trimmed.empty()) {
    return false;
  }

  auto lower_copy = trimmed;
  std::transform(lower_copy.begin(), lower_copy.end(), lower_copy.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  if (lower_copy == "true" || lower_copy == "false") {
    *out = lower_copy;
    return true;
  }

  if ((trimmed.size() >= 2 && trimmed.front() == '\'' && trimmed.back() == '\'') ||
      (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']')) {
    *out = trimmed;
    return true;
  }

  size_t space = trimmed.find(' ');
  if (space != std::string::npos) {
    std::string prefix = trimmed.substr(0, space);
    bool prefix_alpha = !prefix.empty() &&
                        std::all_of(prefix.begin(), prefix.end(), [](unsigned char c) {
                          return std::isalpha(c);
                        });
    if (prefix_alpha) {
      std::string remainder = TrimWhitespace(trimmed.substr(space + 1));
      if (!remainder.empty()) {
        *out = remainder;
        return true;
      }
    }
  }

  *out = trimmed;
  return true;
}

ProxyBackends DetermineProxyBackends() {
  ProxyBackends backends;
  backends.use_env = true;
  backends.use_nm = CommandExists("nmcli");

  auto tokens = DesktopTokens();
  bool gsettings_hint = false;
  bool kde_hint = false;
  bool xfce_hint = false;

  for (const auto& token : tokens) {
    if (token.find("GNOME") != std::string::npos || token.find("UNITY") != std::string::npos ||
        token.find("PANTHEON") != std::string::npos || token.find("POP") != std::string::npos ||
        token.find("COSMIC") != std::string::npos || token.find("BUDGIE") != std::string::npos ||
        token.find("CINNAMON") != std::string::npos || token.find("MATE") != std::string::npos ||
        token.find("DEEPIN") != std::string::npos || token.find("UKUI") != std::string::npos ||
        token.find("LXDE") != std::string::npos || token.find("LXQT") != std::string::npos) {
      gsettings_hint = true;
    }
    if (token.find("KDE") != std::string::npos || token.find("PLASMA") != std::string::npos) {
      kde_hint = true;
    }
    if (token.find("XFCE") != std::string::npos) {
      xfce_hint = true;
    }
  }

  if (gsettings_hint && CommandExists("gsettings")) {
    backends.use_gsettings = true;
  }

  if (kde_hint && CommandExists("kwriteconfig5")) {
    backends.use_kde = true;
  }

  if (xfce_hint && CommandExists("xfconf-query")) {
    backends.use_xfconf = true;
  }

  if (!gsettings_hint && !backends.use_gsettings && CommandExists("gsettings")) {
    // Fallback to gsettings when available, since many desktop environments rely on it.
    backends.use_gsettings = true;
  }

  if (!kde_hint && !backends.use_kde && CommandExists("kwriteconfig5")) {
    // If kwriteconfig5 exists but KDE wasn't hinted, prefer not to change KDE settings implicitly.
    backends.use_kde = false;
  }

  if (!xfce_hint && !backends.use_xfconf) {
    // Leave XFCE untouched unless explicitly detected.
    backends.use_xfconf = false;
  }

  return backends;
}

GsettingsSnapshot* FindGsettingsSnapshot(const std::string& schema) {
  for (auto& entry : g_snapshot.gsettings) {
    if (entry.schema == schema) {
      return &entry;
    }
  }
  return nullptr;
}

GsettingsSnapshot* EnsureGsettingsSnapshot(const std::string& schema) {
  if (auto* existing = FindGsettingsSnapshot(schema)) {
    return existing;
  }
  GsettingsSnapshot snapshot;
  snapshot.schema = schema;
  g_snapshot.gsettings.push_back(snapshot);
  return &g_snapshot.gsettings.back();
}

std::vector<std::string> CandidateGsettingsSchemas() {
  static const std::vector<std::string> kCandidates = {
      "org.gnome.system.proxy",
      "org.gnome.desktop.proxy",
      "org.cinnamon.desktop.proxy",
      "org.mate.proxy",
      "org.mate.desktop.proxy",
      "org.pantheon.desktop.proxy",
      "org.xfce.proxy",
      "org.lxde.proxy",
      "org.budgie.desktop.proxy",
      "com.deepin.daemon.network.proxy",
      "org.freedesktop.proxy",
      "org.ukui.proxy",
      "org.lxqt.proxy"
  };

  std::vector<std::string> result;
  result.reserve(kCandidates.size() + g_snapshot.gsettings.size());

  auto add_unique = [&](const std::string& schema) {
    if (schema.empty()) return;
    if (std::find(result.begin(), result.end(), schema) == result.end()) {
      result.push_back(schema);
    }
  };

  auto tokens = DesktopTokens();
  for (const auto& token : tokens) {
    if (token.find("GNOME") != std::string::npos || token.find("UNITY") != std::string::npos ||
        token.find("PANTHEON") != std::string::npos || token.find("POP") != std::string::npos ||
        token.find("COSMIC") != std::string::npos || token.find("BUDGIE") != std::string::npos) {
      add_unique("org.gnome.system.proxy");
      add_unique("org.gnome.desktop.proxy");
    }
    if (token.find("CINNAMON") != std::string::npos) {
      add_unique("org.cinnamon.desktop.proxy");
    }
    if (token.find("MATE") != std::string::npos) {
      add_unique("org.mate.proxy");
      add_unique("org.mate.desktop.proxy");
    }
    if (token.find("XFCE") != std::string::npos) {
      add_unique("org.xfce.proxy");
    }
    if (token.find("LXDE") != std::string::npos || token.find("LXQT") != std::string::npos ||
        token.find("RASPBERRY") != std::string::npos || token.find("LUMINA") != std::string::npos) {
      add_unique("org.lxde.proxy");
      add_unique("org.lxqt.proxy");
    }
    if (token.find("DEEPIN") != std::string::npos) {
      add_unique("com.deepin.daemon.network.proxy");
    }
    if (token.find("UKUI") != std::string::npos) {
      add_unique("org.ukui.proxy");
    }
  }

  // Preserve any schemas previously captured or loaded from disk first.
  for (const auto& entry : g_snapshot.gsettings) {
    add_unique(entry.schema);
  }

  for (const auto& candidate : kCandidates) {
    add_unique(candidate);
  }

  return result;
}

const std::vector<std::string>& CandidateXfceChannels() {
  static const std::vector<std::string> kChannels = {
      "xfce4-session",
      "xfce4-settings-manager",
      "xfce4-proxy",
      "xfce4-desktop"
  };
  return kChannels;
}

bool XfconfPropertyExists(const std::string& channel, const std::string& property) {
  if (channel.empty()) return false;
  std::string command = "xfconf-query -c " + channel + " -p " + property + " 2>/dev/null";
  CommandResult res = RunCommandQuiet(command);
  return res.exit_code == 0;
}

bool XfconfReadProperty(const std::string& channel, const std::string& property, std::string* value) {
  if (channel.empty()) return false;
  std::string command = "xfconf-query -c " + channel + " -p " + property + " 2>/dev/null";
  CommandResult res = RunCommandQuiet(command);
  if (res.exit_code != 0) {
    return false;
  }
  if (value) {
    *value = TrimWhitespace(res.output);
  }
  return true;
}

void XfconfResetProperty(const std::string& channel, const std::string& property) {
  if (channel.empty()) return;
  std::string command = "xfconf-query -c " + channel + " -p " + property + " -r 2>/dev/null";
  RunCommandQuiet(command);
}

bool XfconfSetValue(const std::string& channel,
                    const std::string& property,
                    const std::string& type,
                    const std::string& value) {
  if (channel.empty()) return false;
  std::string base = "xfconf-query -c " + channel + " -p " + property + " -s " + QuoteForShell(value) + " 2>/dev/null";
  CommandResult res = RunCommandQuiet(base);
  if (res.exit_code == 0) {
    return true;
  }
  std::string create = "xfconf-query -c " + channel + " -p " + property + " -n -t " + type + " -s " + QuoteForShell(value) + " 2>/dev/null";
  res = RunCommandQuiet(create);
  if (res.exit_code != 0) {
    std::ostringstream oss;
    oss << "ProxyManager: failed to set XFCE property " << property << " (type=" << type << ")";
    defyx_core::LogMessage(oss.str());
    return false;
  }
  return true;
}

bool XfconfSetStringList(const std::string& channel,
                         const std::string& property,
                         const std::vector<std::string>& values) {
  if (channel.empty()) return false;
  XfconfResetProperty(channel, property);
  if (values.empty()) {
    return true;
  }
  std::ostringstream create;
  create << "xfconf-query -c " << channel << " -p " << property << " -n";
  for (const auto& value : values) {
    create << " -t string -s " << QuoteForShell(value);
  }
  create << " 2>/dev/null";
  CommandResult res = RunCommandQuiet(create.str());
  if (res.exit_code != 0) {
    std::ostringstream oss;
    oss << "ProxyManager: failed to set XFCE list property " << property;
    defyx_core::LogMessage(oss.str());
    return false;
  }
  return true;
}

std::string DetectXfceChannel() {
  if (!CommandExists("xfconf-query")) return "";
  const auto& channels = CandidateXfceChannels();
  for (const auto& channel : channels) {
    if (XfconfPropertyExists(channel, "/general/ProxyMode")) {
      return channel;
    }
  }

  for (const auto& channel : channels) {
    std::string command = "xfconf-query -c " + channel + " -l 2>/dev/null";
    CommandResult res = RunCommandQuiet(command);
    if (res.exit_code == 0) {
      return channel;
    }
  }

  if (!channels.empty()) {
    return channels.front();
  }
  return "";
}

std::string DefaultConfigDir() {
  const char* xdg = std::getenv("XDG_CONFIG_HOME");
  if (xdg && *xdg) {
    return std::string(xdg);
  }
  const char* home = std::getenv("HOME");
  if (home && *home) {
    return std::string(home) + "/.config";
  }
  return ".";  // fallback to current directory
}

void EnsureSnapshotPath() {
  if (!g_snapshot_path.empty()) return;
  std::string dir = DefaultConfigDir() + "/defyx";
  std::error_code ec;
  std::filesystem::create_directories(dir, ec);
  g_snapshot_path = dir + "/proxy_snapshot.cfg";
}

void SaveSnapshotToDisk(const Snapshot& snapshot) {
  EnsureSnapshotPath();
  std::ofstream ofs(g_snapshot_path.c_str(), std::ios::trunc);
  if (!ofs.is_open()) {
    defyx_core::LogMessage("ProxyManager: failed to open snapshot file for writing");
    return;
  }

  ofs << "version=" << kSnapshotVersion << "\n";
  ofs << "env_captured=" << (snapshot.env.captured ? "1" : "0") << "\n";
  ofs << "env_http=" << Escape(snapshot.env.http) << "\n";
  ofs << "env_https=" << Escape(snapshot.env.https) << "\n";
  ofs << "env_ftp=" << Escape(snapshot.env.ftp) << "\n";
  ofs << "env_all=" << Escape(snapshot.env.all) << "\n";
  ofs << "env_no_proxy=" << Escape(snapshot.env.no_proxy) << "\n";

  ofs << "gsettings_count=" << snapshot.gsettings.size() << "\n";
  for (size_t i = 0; i < snapshot.gsettings.size(); ++i) {
    const auto& entry = snapshot.gsettings[i];
    ofs << "gsettings_" << i << "_schema=" << Escape(entry.schema) << "\n";
    ofs << "gsettings_" << i << "_captured=" << (entry.captured ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_mode=" << Escape(entry.mode) << "\n";
    ofs << "gsettings_" << i << "_http_host=" << Escape(entry.http_host) << "\n";
    ofs << "gsettings_" << i << "_http_port=" << Escape(entry.http_port) << "\n";
    ofs << "gsettings_" << i << "_https_host=" << Escape(entry.https_host) << "\n";
    ofs << "gsettings_" << i << "_https_port=" << Escape(entry.https_port) << "\n";
    ofs << "gsettings_" << i << "_socks_host=" << Escape(entry.socks_host) << "\n";
    ofs << "gsettings_" << i << "_socks_port=" << Escape(entry.socks_port) << "\n";
    ofs << "gsettings_" << i << "_ignore_hosts=" << Escape(entry.ignore_hosts) << "\n";
    ofs << "gsettings_" << i << "_use_same_proxy=" << Escape(entry.use_same_proxy) << "\n";
    ofs << "gsettings_" << i << "_http_enabled=" << Escape(entry.http_enabled) << "\n";
    ofs << "gsettings_" << i << "_https_enabled=" << Escape(entry.https_enabled) << "\n";
    ofs << "gsettings_" << i << "_socks_enabled=" << Escape(entry.socks_enabled) << "\n";
    ofs << "gsettings_" << i << "_ftp_host=" << Escape(entry.ftp_host) << "\n";
    ofs << "gsettings_" << i << "_ftp_port=" << Escape(entry.ftp_port) << "\n";
    ofs << "gsettings_" << i << "_ftp_enabled=" << Escape(entry.ftp_enabled) << "\n";
    ofs << "gsettings_" << i << "_supports_use_same_proxy=" << (entry.supports_use_same_proxy ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_http_enabled=" << (entry.supports_http_enabled ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_https_enabled=" << (entry.supports_https_enabled ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_socks_enabled=" << (entry.supports_socks_enabled ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_ftp=" << (entry.supports_ftp ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_ftp_enabled=" << (entry.supports_ftp_enabled ? "1" : "0") << "\n";
    ofs << "gsettings_" << i << "_supports_ignore_hosts=" << (entry.supports_ignore_hosts ? "1" : "0") << "\n";
  }

  ofs << "kde_captured=" << (snapshot.kde.captured ? "1" : "0") << "\n";
  ofs << "kde_proxy_type=" << Escape(snapshot.kde.proxy_type) << "\n";
  ofs << "kde_http_proxy=" << Escape(snapshot.kde.http_proxy) << "\n";
  ofs << "kde_https_proxy=" << Escape(snapshot.kde.https_proxy) << "\n";
  ofs << "kde_socks_proxy=" << Escape(snapshot.kde.socks_proxy) << "\n";
  ofs << "kde_ftp_proxy=" << Escape(snapshot.kde.ftp_proxy) << "\n";
  ofs << "kde_no_proxy_for=" << Escape(snapshot.kde.no_proxy_for) << "\n";

  ofs << "xfce_captured=" << (snapshot.xfce.captured ? "1" : "0") << "\n";
  ofs << "xfce_channel=" << Escape(snapshot.xfce.channel) << "\n";
  ofs << "xfce_has_mode=" << (snapshot.xfce.has_mode ? "1" : "0") << "\n";
  ofs << "xfce_mode=" << Escape(snapshot.xfce.mode) << "\n";
  ofs << "xfce_has_use_same=" << (snapshot.xfce.has_use_same ? "1" : "0") << "\n";
  ofs << "xfce_use_same=" << Escape(snapshot.xfce.use_same) << "\n";
  ofs << "xfce_has_http_host=" << (snapshot.xfce.has_http_host ? "1" : "0") << "\n";
  ofs << "xfce_http_host=" << Escape(snapshot.xfce.http_host) << "\n";
  ofs << "xfce_has_http_port=" << (snapshot.xfce.has_http_port ? "1" : "0") << "\n";
  ofs << "xfce_http_port=" << Escape(snapshot.xfce.http_port) << "\n";
  ofs << "xfce_has_https_host=" << (snapshot.xfce.has_https_host ? "1" : "0") << "\n";
  ofs << "xfce_https_host=" << Escape(snapshot.xfce.https_host) << "\n";
  ofs << "xfce_has_https_port=" << (snapshot.xfce.has_https_port ? "1" : "0") << "\n";
  ofs << "xfce_https_port=" << Escape(snapshot.xfce.https_port) << "\n";
  ofs << "xfce_has_socks_host=" << (snapshot.xfce.has_socks_host ? "1" : "0") << "\n";
  ofs << "xfce_socks_host=" << Escape(snapshot.xfce.socks_host) << "\n";
  ofs << "xfce_has_socks_port=" << (snapshot.xfce.has_socks_port ? "1" : "0") << "\n";
  ofs << "xfce_socks_port=" << Escape(snapshot.xfce.socks_port) << "\n";
  ofs << "xfce_has_ftp_host=" << (snapshot.xfce.has_ftp_host ? "1" : "0") << "\n";
  ofs << "xfce_ftp_host=" << Escape(snapshot.xfce.ftp_host) << "\n";
  ofs << "xfce_has_ftp_port=" << (snapshot.xfce.has_ftp_port ? "1" : "0") << "\n";
  ofs << "xfce_ftp_port=" << Escape(snapshot.xfce.ftp_port) << "\n";
  ofs << "xfce_has_ignore_hosts=" << (snapshot.xfce.has_ignore_hosts ? "1" : "0") << "\n";
  ofs << "xfce_ignore_hosts=" << Escape(JoinStrings(snapshot.xfce.ignore_hosts, ',')) << "\n";

  ofs << "nm_captured=" << (snapshot.nm.captured ? "1" : "0") << "\n";
  ofs << "nm_count=" << snapshot.nm.connections.size() << "\n";
  for (size_t i = 0; i < snapshot.nm.connections.size(); ++i) {
    const auto& conn = snapshot.nm.connections[i];
    ofs << "nm_" << i << "_name=" << Escape(conn.name) << "\n";
    ofs << "nm_" << i << "_method=" << Escape(conn.method) << "\n";
    ofs << "nm_" << i << "_http=" << Escape(conn.http) << "\n";
    ofs << "nm_" << i << "_https=" << Escape(conn.https) << "\n";
    ofs << "nm_" << i << "_socks=" << Escape(conn.socks) << "\n";
    ofs << "nm_" << i << "_manual_supported=" << (conn.manual_supported ? "1" : "0") << "\n";
  }
}

bool LoadSnapshotFromDisk(Snapshot* snapshot) {
  EnsureSnapshotPath();
  std::ifstream ifs(g_snapshot_path.c_str());
  if (!ifs.is_open()) {
    return false;
  }

  std::map<std::string, std::string> entries;
  std::string line;
  while (std::getline(ifs, line)) {
    size_t pos = line.find('=');
    if (pos == std::string::npos) {
      continue;
    }
    std::string key = line.substr(0, pos);
    std::string value = line.substr(pos + 1);
    entries[key] = Unescape(value);
  }

  if (!entries.count("version")) {
    return false;
  }
  long version = std::strtol(entries["version"].c_str(), nullptr, 10);
  if (version < 1 || version > kSnapshotVersion) {
    return false;
  }

  snapshot->env.captured = entries["env_captured"] == "1";
  snapshot->env.http = entries["env_http"];
  snapshot->env.https = entries["env_https"];
  snapshot->env.ftp = entries["env_ftp"];
  snapshot->env.all = entries["env_all"];
  snapshot->env.no_proxy = entries["env_no_proxy"];

  snapshot->gsettings.clear();
  size_t gsettings_count = 0;
  if (entries.count("gsettings_count")) {
    gsettings_count = static_cast<size_t>(std::strtoul(entries["gsettings_count"].c_str(), nullptr, 10));
  }
  for (size_t i = 0; i < gsettings_count; ++i) {
    GsettingsSnapshot gs;
    std::string prefix = "gsettings_" + std::to_string(i) + "_";
    gs.schema = entries[prefix + "schema"];
    gs.captured = entries[prefix + "captured"] == "1";
    gs.mode = entries[prefix + "mode"];
    gs.http_host = entries[prefix + "http_host"];
    gs.http_port = entries[prefix + "http_port"];
    gs.https_host = entries[prefix + "https_host"];
    gs.https_port = entries[prefix + "https_port"];
    gs.socks_host = entries[prefix + "socks_host"];
    gs.socks_port = entries[prefix + "socks_port"];
    gs.ignore_hosts = entries[prefix + "ignore_hosts"];
    gs.use_same_proxy = entries[prefix + "use_same_proxy"];
    gs.http_enabled = entries[prefix + "http_enabled"];
    gs.https_enabled = entries[prefix + "https_enabled"];
    gs.socks_enabled = entries[prefix + "socks_enabled"];
    gs.ftp_host = entries[prefix + "ftp_host"];
    gs.ftp_port = entries[prefix + "ftp_port"];
    gs.ftp_enabled = entries[prefix + "ftp_enabled"];
    gs.supports_use_same_proxy = entries[prefix + "supports_use_same_proxy"] == "1";
    gs.supports_http_enabled = entries[prefix + "supports_http_enabled"] == "1";
    gs.supports_https_enabled = entries[prefix + "supports_https_enabled"] == "1";
    gs.supports_socks_enabled = entries[prefix + "supports_socks_enabled"] == "1";
    gs.supports_ftp = entries[prefix + "supports_ftp"] == "1";
    gs.supports_ftp_enabled = entries[prefix + "supports_ftp_enabled"] == "1";
    gs.supports_ignore_hosts = entries[prefix + "supports_ignore_hosts"] == "1";
    snapshot->gsettings.push_back(gs);
  }

  snapshot->kde.captured = entries["kde_captured"] == "1";
  snapshot->kde.proxy_type = entries["kde_proxy_type"];
  snapshot->kde.http_proxy = entries["kde_http_proxy"];
  snapshot->kde.https_proxy = entries["kde_https_proxy"];
  snapshot->kde.socks_proxy = entries["kde_socks_proxy"];
  snapshot->kde.ftp_proxy = entries["kde_ftp_proxy"];
  snapshot->kde.no_proxy_for = entries["kde_no_proxy_for"];

  snapshot->xfce = {};
  if (entries.count("xfce_captured")) {
    snapshot->xfce.captured = entries["xfce_captured"] == "1";
    if (entries.count("xfce_channel")) {
      snapshot->xfce.channel = entries["xfce_channel"];
    }
    snapshot->xfce.has_mode = entries["xfce_has_mode"] == "1";
    snapshot->xfce.mode = entries["xfce_mode"];
    snapshot->xfce.has_use_same = entries["xfce_has_use_same"] == "1";
    snapshot->xfce.use_same = entries["xfce_use_same"];
    snapshot->xfce.has_http_host = entries["xfce_has_http_host"] == "1";
    snapshot->xfce.http_host = entries["xfce_http_host"];
    snapshot->xfce.has_http_port = entries["xfce_has_http_port"] == "1";
    snapshot->xfce.http_port = entries["xfce_http_port"];
    snapshot->xfce.has_https_host = entries["xfce_has_https_host"] == "1";
    snapshot->xfce.https_host = entries["xfce_https_host"];
    snapshot->xfce.has_https_port = entries["xfce_has_https_port"] == "1";
    snapshot->xfce.https_port = entries["xfce_https_port"];
    snapshot->xfce.has_socks_host = entries["xfce_has_socks_host"] == "1";
    snapshot->xfce.socks_host = entries["xfce_socks_host"];
    snapshot->xfce.has_socks_port = entries["xfce_has_socks_port"] == "1";
    snapshot->xfce.socks_port = entries["xfce_socks_port"];
    snapshot->xfce.has_ftp_host = entries["xfce_has_ftp_host"] == "1";
    snapshot->xfce.ftp_host = entries["xfce_ftp_host"];
    snapshot->xfce.has_ftp_port = entries["xfce_has_ftp_port"] == "1";
    snapshot->xfce.ftp_port = entries["xfce_ftp_port"];
    snapshot->xfce.has_ignore_hosts = entries["xfce_has_ignore_hosts"] == "1";
    snapshot->xfce.ignore_hosts = SplitString(entries["xfce_ignore_hosts"], ',');
  }

  snapshot->nm.captured = entries["nm_captured"] == "1";
  snapshot->nm.connections.clear();
  size_t nm_count = 0;
  if (entries.count("nm_count")) {
    nm_count = static_cast<size_t>(std::strtoul(entries["nm_count"].c_str(), nullptr, 10));
  }
  for (size_t i = 0; i < nm_count; ++i) {
    NmConnectionSnapshot conn;
    conn.name = entries["nm_" + std::to_string(i) + "_name"];
    conn.method = entries["nm_" + std::to_string(i) + "_method"];
    conn.http = entries["nm_" + std::to_string(i) + "_http"];
    conn.https = entries["nm_" + std::to_string(i) + "_https"];
    conn.socks = entries["nm_" + std::to_string(i) + "_socks"];
    std::string manual_supported_key = "nm_" + std::to_string(i) + "_manual_supported";
    if (entries.count(manual_supported_key)) {
      conn.manual_supported = entries[manual_supported_key] == "1";
    }
    snapshot->nm.connections.push_back(conn);
  }

  return true;
}

void ClearSnapshotFile() {
  EnsureSnapshotPath();
  std::error_code ec;
  std::filesystem::remove(g_snapshot_path, ec);
}

std::string BuildProxyUrl(const std::string& scheme,
                          const std::string& host,
                          int port) {
  std::ostringstream oss;
  oss << scheme << "://" << host << ":" << port;
  return oss.str();
}

void CaptureEnv() {
  if (g_snapshot.env.captured) return;
  g_snapshot.env.captured = true;
  const char* val = std::getenv("http_proxy");
  if (val) g_snapshot.env.http = val;
  val = std::getenv("https_proxy");
  if (val) g_snapshot.env.https = val;
  val = std::getenv("ftp_proxy");
  if (val) g_snapshot.env.ftp = val;
  val = std::getenv("all_proxy");
  if (val) g_snapshot.env.all = val;
  val = std::getenv("no_proxy");
  if (val) g_snapshot.env.no_proxy = val;
}

void ApplyEnv(const ProxyConfig& config) {
  const std::string proxy_url = BuildProxyUrl(config.scheme.empty() ? "http" : config.scheme,
                                              config.host, config.port);
  setenv("http_proxy", proxy_url.c_str(), 1);
  setenv("https_proxy", proxy_url.c_str(), 1);
  setenv("ftp_proxy", proxy_url.c_str(), 1);
  setenv("all_proxy", proxy_url.c_str(), 1);
  setenv("HTTP_PROXY", proxy_url.c_str(), 1);
  setenv("HTTPS_PROXY", proxy_url.c_str(), 1);
  setenv("FTP_PROXY", proxy_url.c_str(), 1);
  setenv("ALL_PROXY", proxy_url.c_str(), 1);

  std::string no_proxy = config.no_proxy.empty() ? "localhost,127.0.0.1,::1" : config.no_proxy;
  setenv("no_proxy", no_proxy.c_str(), 1);
  setenv("NO_PROXY", no_proxy.c_str(), 1);
}

void RestoreEnv() {
  if (!g_snapshot.env.captured) return;
  if (g_snapshot.env.http.empty()) unsetenv("http_proxy");
  else setenv("http_proxy", g_snapshot.env.http.c_str(), 1);

  if (g_snapshot.env.https.empty()) unsetenv("https_proxy");
  else setenv("https_proxy", g_snapshot.env.https.c_str(), 1);

  if (g_snapshot.env.ftp.empty()) unsetenv("ftp_proxy");
  else setenv("ftp_proxy", g_snapshot.env.ftp.c_str(), 1);

  if (g_snapshot.env.all.empty()) unsetenv("all_proxy");
  else setenv("all_proxy", g_snapshot.env.all.c_str(), 1);

  if (g_snapshot.env.no_proxy.empty()) unsetenv("no_proxy");
  else setenv("no_proxy", g_snapshot.env.no_proxy.c_str(), 1);

  if (g_snapshot.env.http.empty()) unsetenv("HTTP_PROXY");
  else setenv("HTTP_PROXY", g_snapshot.env.http.c_str(), 1);

  if (g_snapshot.env.https.empty()) unsetenv("HTTPS_PROXY");
  else setenv("HTTPS_PROXY", g_snapshot.env.https.c_str(), 1);

  if (g_snapshot.env.ftp.empty()) unsetenv("FTP_PROXY");
  else setenv("FTP_PROXY", g_snapshot.env.ftp.c_str(), 1);

  if (g_snapshot.env.all.empty()) unsetenv("ALL_PROXY");
  else setenv("ALL_PROXY", g_snapshot.env.all.c_str(), 1);

  if (g_snapshot.env.no_proxy.empty()) unsetenv("NO_PROXY");
  else setenv("NO_PROXY", g_snapshot.env.no_proxy.c_str(), 1);
}

std::vector<std::string> DiscoverGsettingsSchemas() {
  std::vector<std::string> discovered;
  if (!CommandExists("gsettings")) {
    return discovered;
  }

  auto candidates = CandidateGsettingsSchemas();
  auto add_if_supported = [&](const std::string& schema) {
    if (schema.empty()) return;
    if (std::find(discovered.begin(), discovered.end(), schema) != discovered.end()) return;
    if (!GSettingsKeyExists(schema, "mode")) return;
    if (!GSettingsKeyExists(MakeSubSchema(schema, "http"), "host")) return;
    discovered.push_back(schema);
  };

  for (const auto& schema : candidates) {
    add_if_supported(schema);
  }

  auto collect_from_command = [&](const std::string& command) {
    CommandResult res = RunCommandQuiet(command);
    if (res.exit_code != 0) return;
    std::stringstream ss(res.output);
    std::string line;
    while (std::getline(ss, line)) {
      std::string trimmed = TrimWhitespace(line);
      if (trimmed.find(".proxy") == std::string::npos) continue;
      add_if_supported(trimmed);
    }
  };

  collect_from_command("gsettings list-schemas");
  collect_from_command("gsettings list-relocatable-schemas");

  return discovered;
}

void CaptureGsettings() {
  if (!CommandExists("gsettings")) return;

  auto schemas = DiscoverGsettingsSchemas();
  for (const auto& schema : schemas) {
    GsettingsSnapshot* snapshot = EnsureGsettingsSnapshot(schema);
    if (!snapshot || snapshot->captured) {
      continue;
    }

    snapshot->captured = true;

    auto capture_key = [&](const std::string& full_schema, const std::string& key, std::string* target, bool* supported_flag = nullptr) {
      if (!GSettingsKeyExists(full_schema, key)) {
        if (supported_flag) *supported_flag = false;
        return false;
      }
      CommandResult res = RunCommand("gsettings get " + full_schema + " " + key);
      if (res.exit_code == 0) {
        if (target) *target = res.output;
        if (supported_flag) *supported_flag = true;
        return true;
      }
      if (supported_flag) *supported_flag = false;
      return false;
    };

    capture_key(schema, "mode", &snapshot->mode);
    snapshot->supports_use_same_proxy = false;
    capture_key(schema, "use-same-proxy", &snapshot->use_same_proxy, &snapshot->supports_use_same_proxy);
    snapshot->supports_ignore_hosts = false;
    capture_key(schema, "ignore-hosts", &snapshot->ignore_hosts, &snapshot->supports_ignore_hosts);

    auto capture_group = [&](const std::string& group, std::string* host, std::string* port, std::string* enabled, bool* enabled_supported) {
      std::string sub_schema = MakeSubSchema(schema, group);
      capture_key(sub_schema, "host", host);
      capture_key(sub_schema, "port", port);
      if (enabled && enabled_supported) {
        *enabled_supported = false;
        capture_key(sub_schema, "enabled", enabled, enabled_supported);
      }
    };

    capture_group("http", &snapshot->http_host, &snapshot->http_port, &snapshot->http_enabled, &snapshot->supports_http_enabled);
    capture_group("https", &snapshot->https_host, &snapshot->https_port, &snapshot->https_enabled, &snapshot->supports_https_enabled);
    capture_group("socks", &snapshot->socks_host, &snapshot->socks_port, &snapshot->socks_enabled, &snapshot->supports_socks_enabled);

    std::string ftp_enabled_value;
    bool ftp_enabled_supported = false;
    capture_group("ftp", &snapshot->ftp_host, &snapshot->ftp_port, &ftp_enabled_value, &ftp_enabled_supported);
    snapshot->supports_ftp = !snapshot->ftp_host.empty() || !snapshot->ftp_port.empty();
    if (ftp_enabled_supported) {
      snapshot->supports_ftp_enabled = true;
      snapshot->ftp_enabled = ftp_enabled_value;
    }
  }
}

std::string QuoteForGSettings(const std::string& value) {
  std::string trimmed = value;
  // Remove trailing newline if exists
  while (!trimmed.empty() && (trimmed.back() == '\n' || trimmed.back() == '\r')) {
    trimmed.pop_back();
  }
  if (trimmed.size() >= 2 && trimmed.front() == '\'' && trimmed.back() == '\'') {
    return trimmed;
  }
  return "'" + trimmed + "'";
}

bool ApplyGsettingsSchema(const ProxyConfig& config, GsettingsSnapshot* snapshot) {
  if (!snapshot) return false;
  const std::string& schema = snapshot->schema;
  if (!GSettingsKeyExists(schema, "mode")) return false;

  std::ostringstream ignore;
  std::string no_proxy = config.no_proxy.empty() ? "localhost,127.0.0.1,::1" : config.no_proxy;
  ignore << "[";
  std::stringstream ss(no_proxy);
  std::string item;
  bool first = true;
  while (std::getline(ss, item, ',')) {
    if (item.empty()) continue;
    if (!first) ignore << ", ";
    ignore << "'" << item << "'";
    first = false;
  }
  ignore << "]";

  std::ostringstream port_str;
  port_str << config.port;

  std::string host_quoted = QuoteForGSettings(config.host);
  std::string port_command = port_str.str();
  RunCommand("gsettings set " + schema + " mode 'manual'");

  bool use_same_proxy_supported = snapshot->supports_use_same_proxy || GSettingsKeyExists(schema, "use-same-proxy");
  if (use_same_proxy_supported) {
    snapshot->supports_use_same_proxy = true;
    RunCommand("gsettings set " + schema + " use-same-proxy true");
  }

  auto apply_group = [&](const std::string& group, bool enable_flag) {
    std::string sub_schema = MakeSubSchema(schema, group);
    if (GSettingsKeyExists(sub_schema, "host")) {
      RunCommand("gsettings set " + sub_schema + " host " + host_quoted);
    }
    if (GSettingsKeyExists(sub_schema, "port")) {
      RunCommand("gsettings set " + sub_schema + " port " + port_command);
    }
    if (enable_flag && GSettingsKeyExists(sub_schema, "enabled")) {
      RunCommand("gsettings set " + sub_schema + " enabled true");
    }
  };

  apply_group("http", true);
  apply_group("https", true);
  apply_group("socks", true);

  std::string ftp_schema = MakeSubSchema(schema, "ftp");
  bool ftp_supported = snapshot->supports_ftp || GSettingsKeyExists(ftp_schema, "host") || GSettingsKeyExists(ftp_schema, "port");
  if (ftp_supported) {
    if (GSettingsKeyExists(ftp_schema, "host")) {
      RunCommand("gsettings set " + ftp_schema + " host " + host_quoted);
    }
    if (GSettingsKeyExists(ftp_schema, "port")) {
      RunCommand("gsettings set " + ftp_schema + " port " + port_command);
    }
    bool ftp_enable_supported = snapshot->supports_ftp_enabled || GSettingsKeyExists(ftp_schema, "enabled");
    if (ftp_enable_supported) {
      snapshot->supports_ftp_enabled = true;
      RunCommand("gsettings set " + ftp_schema + " enabled true");
    }
    snapshot->supports_ftp = true;
  }

  bool ignore_hosts_supported = snapshot->supports_ignore_hosts || GSettingsKeyExists(schema, "ignore-hosts");
  if (ignore_hosts_supported) {
    snapshot->supports_ignore_hosts = true;
    RunCommand("gsettings set " + schema + " ignore-hosts \"" + ignore.str() + "\"");
  }

  auto log_if_mismatch = [&](const std::string& label, const std::string& full_schema, const std::string& key, const std::string& expected, const std::string& alt_expected = std::string()) {
    CommandResult current = RunCommand("gsettings get " + full_schema + " " + key);
    if (current.exit_code != 0) return;
    std::string trimmed = TrimWhitespace(current.output);
    if (trimmed != expected && (alt_expected.empty() || trimmed != alt_expected)) {
      defyx_core::LogMessage("ProxyManager: gsettings(" + schema + ") " + label + " mismatch -> got: " + trimmed + ", expected: " + expected);
    }
  };

  log_if_mismatch("mode", schema, "mode", "'manual'");
  std::string expected_host = "'" + config.host + "'";
  std::string http_schema = MakeSubSchema(schema, "http");
  log_if_mismatch("http host", http_schema, "host", expected_host);
  std::string port_value = std::to_string(config.port);
  log_if_mismatch("http port", http_schema, "port", port_value, "uint32 " + port_value);

  return true;
}

bool ApplyGsettings(const ProxyConfig& config) {
  if (!CommandExists("gsettings")) return false;
  CaptureGsettings();

  bool applied = false;
  auto schemas = DiscoverGsettingsSchemas();
  for (const auto& schema : schemas) {
    GsettingsSnapshot* snapshot = EnsureGsettingsSnapshot(schema);
    if (ApplyGsettingsSchema(config, snapshot)) {
      applied = true;
    }
  }
  return applied;
}

void RestoreGsettings() {
  if (!CommandExists("gsettings")) return;

  auto set_if_supported = [](const std::string& schema, const std::string& key, const std::string& value, bool supported) {
    if (schema.empty()) {
      defyx_core::LogMessage("ProxyManager: skipping gsettings restore for empty schema key=" + key);
      return;
    }
    if (!supported) return;
    if (value.empty()) return;
    if (!GSettingsKeyExists(schema, key)) return;
    std::string formatted;
    if (!NormalizeGsettingsValueForSet(value, &formatted)) return;
    RunCommand("gsettings set " + schema + " " + key + " " + formatted);
  };

  for (auto& snapshot : g_snapshot.gsettings) {
    if (!snapshot.captured) continue;
    if (!GSettingsKeyExists(snapshot.schema, "mode")) continue;

    set_if_supported(snapshot.schema, "mode", snapshot.mode, true);
    set_if_supported(snapshot.schema, "use-same-proxy", snapshot.use_same_proxy, snapshot.supports_use_same_proxy);
    set_if_supported(snapshot.schema, "ignore-hosts", snapshot.ignore_hosts, snapshot.supports_ignore_hosts);

    auto set_group = [&](const std::string& group, const std::string& host_val, const std::string& port_val, const std::string& enabled_val, bool enabled_supported) {
      std::string sub_schema = MakeSubSchema(snapshot.schema, group);
      set_if_supported(sub_schema, "host", host_val, !host_val.empty());
      set_if_supported(sub_schema, "port", port_val, !port_val.empty());
      set_if_supported(sub_schema, "enabled", enabled_val, enabled_supported);
    };

    set_group("http", snapshot.http_host, snapshot.http_port, snapshot.http_enabled, snapshot.supports_http_enabled);
    set_group("https", snapshot.https_host, snapshot.https_port, snapshot.https_enabled, snapshot.supports_https_enabled);
    set_group("socks", snapshot.socks_host, snapshot.socks_port, snapshot.socks_enabled, snapshot.supports_socks_enabled);
    set_group("ftp", snapshot.ftp_host, snapshot.ftp_port, snapshot.ftp_enabled, snapshot.supports_ftp_enabled);
  }
}

void CaptureKde() {
  if (g_snapshot.kde.captured) return;
  if (!CommandExists("kreadconfig5")) return;

  g_snapshot.kde.captured = true;
  g_snapshot.kde.proxy_type = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType").output;
  g_snapshot.kde.http_proxy = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key httpProxy").output;
  g_snapshot.kde.https_proxy = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key httpsProxy").output;
  g_snapshot.kde.socks_proxy = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key socksProxy").output;
  g_snapshot.kde.ftp_proxy = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key ftpProxy").output;
  g_snapshot.kde.no_proxy_for = RunCommand("kreadconfig5 --file kioslaverc --group 'Proxy Settings' --key NoProxyFor").output;
}

std::string QuoteForShell(const std::string& value) {
  std::ostringstream oss;
  oss << "'";
  for (size_t i = 0; i < value.size(); ++i) {
    if (value[i] == '\'') {
      oss << "'\\''";
    } else {
      oss << value[i];
    }
  }
  oss << "'";
  return oss.str();
}
bool ApplyKde(const ProxyConfig& config) {
  if (!CommandExists("kwriteconfig5")) return false;

  std::string proxy_url = BuildProxyUrl(config.scheme.empty() ? "http" : config.scheme,
                                        config.host, config.port);
  std::string proxy_socks = BuildProxyUrl(config.scheme.empty() ? "socks5" : config.scheme,
                                          config.host, config.port);
  std::string no_proxy = config.no_proxy.empty() ? "localhost,127.0.0.1,::1" : config.no_proxy;

  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 1");
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpProxy " + QuoteForShell(proxy_url));
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpsProxy " + QuoteForShell(proxy_url));
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key socksProxy " + QuoteForShell(proxy_socks));
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ftpProxy " + QuoteForShell(proxy_url));
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key NoProxyFor " + QuoteForShell(no_proxy));
  if (CommandExists("qdbus")) {
    RunCommandQuiet("qdbus org.kde.kded5 /kded org.kde.kded5.loadModule proxy >/dev/null 2>&1");
  }
  return true;
}

void RestoreKde() {
  if (!g_snapshot.kde.captured || !CommandExists("kwriteconfig5")) return;

  auto write_key = [](const std::string& key, const std::string& value) {
    if (value.empty()) {
      RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key " + key + " --delete");
      return;
    }
    std::string trimmed = value;
    while (!trimmed.empty() && (trimmed.back() == '\n' || trimmed.back() == '\r')) {
      trimmed.pop_back();
    }
    RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key " + key + " " + QuoteForShell(trimmed));
  };

  std::string proxy_type = g_snapshot.kde.proxy_type;
  while (!proxy_type.empty() && (proxy_type.back() == '\n' || proxy_type.back() == '\r')) {
    proxy_type.pop_back();
  }
  if (proxy_type.empty()) proxy_type = "0";
  RunCommand("kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType " + proxy_type);

  write_key("httpProxy", g_snapshot.kde.http_proxy);
  write_key("httpsProxy", g_snapshot.kde.https_proxy);
  write_key("socksProxy", g_snapshot.kde.socks_proxy);
  write_key("ftpProxy", g_snapshot.kde.ftp_proxy);
  write_key("NoProxyFor", g_snapshot.kde.no_proxy_for);

  if (CommandExists("qdbus")) {
    RunCommandQuiet("qdbus org.kde.kded5 /kded org.kde.kded5.loadModule proxy >/dev/null 2>&1");
  }
}

void CaptureXfce() {
  if (g_snapshot.xfce.captured) return;
  if (!CommandExists("xfconf-query")) return;

  std::string channel = g_snapshot.xfce.channel.empty() ? DetectXfceChannel() : g_snapshot.xfce.channel;
  if (channel.empty()) {
    defyx_core::LogMessage("ProxyManager: XFCE xfconf channel not found; skipping capture");
    return;
  }

  g_snapshot.xfce.captured = true;
  g_snapshot.xfce.channel = channel;

  auto capture_string = [&](const std::string& property, bool* has_flag, std::string* target) {
    std::string value;
    if (XfconfReadProperty(channel, property, &value)) {
      *has_flag = true;
      *target = value;
    } else {
      *has_flag = false;
      target->clear();
    }
  };

  capture_string("/general/ProxyMode", &g_snapshot.xfce.has_mode, &g_snapshot.xfce.mode);
  capture_string("/general/ProxyUseSame", &g_snapshot.xfce.has_use_same, &g_snapshot.xfce.use_same);
  capture_string("/general/ProxyHttpHost", &g_snapshot.xfce.has_http_host, &g_snapshot.xfce.http_host);
  capture_string("/general/ProxyHttpPort", &g_snapshot.xfce.has_http_port, &g_snapshot.xfce.http_port);
  capture_string("/general/ProxyHttpsHost", &g_snapshot.xfce.has_https_host, &g_snapshot.xfce.https_host);
  capture_string("/general/ProxyHttpsPort", &g_snapshot.xfce.has_https_port, &g_snapshot.xfce.https_port);
  capture_string("/general/ProxySocksHost", &g_snapshot.xfce.has_socks_host, &g_snapshot.xfce.socks_host);
  capture_string("/general/ProxySocksPort", &g_snapshot.xfce.has_socks_port, &g_snapshot.xfce.socks_port);
  capture_string("/general/ProxyFtpHost", &g_snapshot.xfce.has_ftp_host, &g_snapshot.xfce.ftp_host);
  capture_string("/general/ProxyFtpPort", &g_snapshot.xfce.has_ftp_port, &g_snapshot.xfce.ftp_port);

  std::string ignore_raw;
  if (XfconfReadProperty(channel, "/general/ProxyIgnoreHosts", &ignore_raw)) {
    g_snapshot.xfce.has_ignore_hosts = true;
    g_snapshot.xfce.ignore_hosts = ParseXfconfList(ignore_raw);
  } else {
    g_snapshot.xfce.has_ignore_hosts = false;
    g_snapshot.xfce.ignore_hosts.clear();
  }
}

bool ApplyXfce(const ProxyConfig& config) {
  if (!CommandExists("xfconf-query")) return false;

  std::string channel = g_snapshot.xfce.channel.empty() ? DetectXfceChannel() : g_snapshot.xfce.channel;
  if (channel.empty()) {
    defyx_core::LogMessage("ProxyManager: XFCE xfconf channel not found; cannot apply proxy");
    return false;
  }
  g_snapshot.xfce.channel = channel;

  bool any_applied = false;
  bool ok = true;

  ok &= XfconfSetValue(channel, "/general/ProxyMode", "string", "manual");
  ok &= XfconfSetValue(channel, "/general/ProxyUseSame", "bool", "true");
  ok &= XfconfSetValue(channel, "/general/ProxyHttpHost", "string", config.host);
  ok &= XfconfSetValue(channel, "/general/ProxyHttpPort", "int", std::to_string(config.port));
  ok &= XfconfSetValue(channel, "/general/ProxyHttpsHost", "string", config.host);
  ok &= XfconfSetValue(channel, "/general/ProxyHttpsPort", "int", std::to_string(config.port));
  ok &= XfconfSetValue(channel, "/general/ProxySocksHost", "string", config.host);
  ok &= XfconfSetValue(channel, "/general/ProxySocksPort", "int", std::to_string(config.port));
  ok &= XfconfSetValue(channel, "/general/ProxyFtpHost", "string", config.host);
  ok &= XfconfSetValue(channel, "/general/ProxyFtpPort", "int", std::to_string(config.port));

  std::vector<std::string> ignore_hosts = BuildNoProxyList(config.no_proxy);
  ok &= XfconfSetStringList(channel, "/general/ProxyIgnoreHosts", ignore_hosts);

  any_applied = ok;
  if (!ok) {
    defyx_core::LogMessage("ProxyManager: failed to update all XFCE proxy keys");
  }

  return any_applied;
}

void RestoreXfce() {
  if (!g_snapshot.xfce.captured) return;
  if (!CommandExists("xfconf-query")) return;

  std::string channel = g_snapshot.xfce.channel.empty() ? DetectXfceChannel() : g_snapshot.xfce.channel;
  if (channel.empty()) {
    defyx_core::LogMessage("ProxyManager: XFCE xfconf channel not found; cannot restore snapshot");
    return;
  }
  g_snapshot.xfce.channel = channel;

  auto restore_value = [&](const std::string& property, bool has_value, const std::string& value, const std::string& type) {
    if (has_value) {
      XfconfSetValue(channel, property, type, value);
    } else {
      XfconfResetProperty(channel, property);
    }
  };

  restore_value("/general/ProxyMode", g_snapshot.xfce.has_mode, g_snapshot.xfce.mode, "string");
  restore_value("/general/ProxyUseSame", g_snapshot.xfce.has_use_same, g_snapshot.xfce.use_same.empty() ? "false" : g_snapshot.xfce.use_same, "bool");
  restore_value("/general/ProxyHttpHost", g_snapshot.xfce.has_http_host, g_snapshot.xfce.http_host, "string");
  restore_value("/general/ProxyHttpPort", g_snapshot.xfce.has_http_port, g_snapshot.xfce.http_port, "int");
  restore_value("/general/ProxyHttpsHost", g_snapshot.xfce.has_https_host, g_snapshot.xfce.https_host, "string");
  restore_value("/general/ProxyHttpsPort", g_snapshot.xfce.has_https_port, g_snapshot.xfce.https_port, "int");
  restore_value("/general/ProxySocksHost", g_snapshot.xfce.has_socks_host, g_snapshot.xfce.socks_host, "string");
  restore_value("/general/ProxySocksPort", g_snapshot.xfce.has_socks_port, g_snapshot.xfce.socks_port, "int");
  restore_value("/general/ProxyFtpHost", g_snapshot.xfce.has_ftp_host, g_snapshot.xfce.ftp_host, "string");
  restore_value("/general/ProxyFtpPort", g_snapshot.xfce.has_ftp_port, g_snapshot.xfce.ftp_port, "int");

  if (g_snapshot.xfce.has_ignore_hosts) {
    XfconfSetStringList(channel, "/general/ProxyIgnoreHosts", g_snapshot.xfce.ignore_hosts);
  } else {
    XfconfResetProperty(channel, "/general/ProxyIgnoreHosts");
  }
}

void CaptureNM() {
  if (g_snapshot.nm.captured) return;
  if (!CommandExists("nmcli")) return;

  CommandResult res = RunCommand("nmcli -t -f NAME connection show --active");
  if (res.exit_code != 0) return;

  g_snapshot.nm.captured = true;
  g_snapshot.nm.connections.clear();

  std::stringstream ss(res.output);
  std::string line;
  while (std::getline(ss, line)) {
    if (line.empty()) continue;
    NmConnectionSnapshot snapshot;
    snapshot.name = line;
    std::string quoted = QuoteForShell(line);
    snapshot.method = RunCommand("nmcli -g proxy.method connection show " + quoted + " 2>/dev/null").output;

    CommandResult show_output = RunCommandQuiet("nmcli connection show " + quoted + " 2>/dev/null");
    if (show_output.exit_code == 0 &&
        (show_output.output.find("proxy.http") != std::string::npos ||
         show_output.output.find("proxy.https") != std::string::npos ||
         show_output.output.find("proxy.socks") != std::string::npos)) {
      snapshot.manual_supported = true;
      snapshot.http = RunCommand("nmcli -g proxy.http connection show " + quoted + " 2>/dev/null").output;
      snapshot.https = RunCommand("nmcli -g proxy.https connection show " + quoted + " 2>/dev/null").output;
      snapshot.socks = RunCommand("nmcli -g proxy.socks connection show " + quoted + " 2>/dev/null").output;
    }
    g_snapshot.nm.connections.push_back(snapshot);
  }
}

bool ApplyNM(const ProxyConfig& config) {
  if (!CommandExists("nmcli")) return false;
  std::string proxy_url = BuildProxyUrl(config.scheme.empty() ? "http" : config.scheme,
                                        config.host, config.port);
  std::string socks_url = BuildProxyUrl(config.scheme.empty() ? "socks5" : config.scheme,
                                        config.host, config.port);

  bool applied = false;
  for (size_t i = 0; i < g_snapshot.nm.connections.size(); ++i) {
    const NmConnectionSnapshot& conn_snapshot = g_snapshot.nm.connections[i];
    const std::string& name = conn_snapshot.name;
    if (name.empty()) continue;
    std::string quoted = QuoteForShell(name);
    if (!conn_snapshot.manual_supported) {
      defyx_core::LogMessage("ProxyManager: skipping NetworkManager proxy update for " + name + " (proxy.http unsupported)");
      continue;
    }

    CommandResult method_result = RunCommand("nmcli connection modify " + quoted + " proxy.method manual >/dev/null 2>&1");
    if (method_result.exit_code != 0) {
      defyx_core::LogMessage("ProxyManager: skipping NetworkManager proxy update for " + name + " (manual method unavailable)");
      continue;
    }

    RunCommand("nmcli connection modify " + quoted + " proxy.http " + QuoteForShell(proxy_url) + " >/dev/null 2>&1");
    RunCommand("nmcli connection modify " + quoted + " proxy.https " + QuoteForShell(proxy_url) + " >/dev/null 2>&1");
    RunCommand("nmcli connection modify " + quoted + " proxy.socks " + QuoteForShell(socks_url) + " >/dev/null 2>&1");
    RunCommand("nmcli connection up " + quoted + " >/dev/null 2>&1");
    applied = true;
  }

  return applied;
}

void RestoreNM() {
  if (!g_snapshot.nm.captured || !CommandExists("nmcli")) return;
  for (size_t i = 0; i < g_snapshot.nm.connections.size(); ++i) {
    const NmConnectionSnapshot& conn = g_snapshot.nm.connections[i];
    if (conn.name.empty()) continue;
    if (!conn.manual_supported) continue;
    std::string quoted = QuoteForShell(conn.name);

    std::string method = conn.method;
    while (!method.empty() && (method.back() == '\n' || method.back() == '\r')) {
      method.pop_back();
    }
    if (method.empty()) method = "none";
    RunCommand("nmcli connection modify " + quoted + " proxy.method " + method + " >/dev/null 2>&1");

    auto restore_field = [&](const std::string& key, const std::string& value) {
      std::string trimmed = value;
      while (!trimmed.empty() && (trimmed.back() == '\n' || trimmed.back() == '\r')) {
        trimmed.pop_back();
      }
      if (trimmed.empty()) {
        RunCommand("nmcli connection modify " + quoted + " " + key + " '' >/dev/null 2>&1");
      } else {
        RunCommand("nmcli connection modify " + quoted + " " + key + " " + QuoteForShell(trimmed) + " >/dev/null 2>&1");
      }
    };

    restore_field("proxy.http", conn.http);
    restore_field("proxy.https", conn.https);
    restore_field("proxy.socks", conn.socks);
    RunCommand("nmcli connection up " + quoted + " >/dev/null 2>&1");
  }
}

void CaptureAll() {
  CaptureEnv();
  CaptureGsettings();
  CaptureXfce();
  CaptureKde();
  CaptureNM();
}

ApplyResults ApplyAll(const ProxyConfig& config, const ProxyBackends& backends) {
  ApplyResults results;
  if (backends.use_env) {
    ApplyEnv(config);
    results.env_applied = true;
  }
  if (backends.use_gsettings) {
    results.gsettings_applied = ApplyGsettings(config);
  }
  if (backends.use_xfconf) {
    results.xfce_applied = ApplyXfce(config);
  }
  if (backends.use_kde) {
    results.kde_applied = ApplyKde(config);
  }
  if (backends.use_nm) {
    results.nm_applied = ApplyNM(config);
  }
  return results;
}

void RestoreAll() {
  RestoreEnv();
  RestoreGsettings();
  RestoreXfce();
  RestoreKde();
  RestoreNM();
}

}  // namespace

bool ApplySystemProxy(const ProxyConfig& config) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (config.host.empty() || config.port <= 0) {
    defyx_core::LogMessage("ProxyManager: invalid proxy configuration");
    return false;
  }

  ProxyBackends backends = DetermineProxyBackends();
  std::vector<std::string> backend_names;
  if (backends.use_env) backend_names.push_back("env");
  if (backends.use_gsettings) backend_names.push_back("gsettings");
  if (backends.use_xfconf) backend_names.push_back("xfce");
  if (backends.use_kde) backend_names.push_back("kde");
  if (backends.use_nm) backend_names.push_back("network-manager");
  if (backend_names.empty()) backend_names.push_back("env");
  defyx_core::LogMessage("ProxyManager: desktop detection -> " + JoinStrings(backend_names, ", "));

  if (!g_applied) {
    CaptureAll();
    SaveSnapshotToDisk(g_snapshot);
  }

  ApplyResults results = ApplyAll(config, backends);
  g_applied = true;
  defyx_core::LogMessage("ProxyManager: applied system proxy");
  bool attempted_desktop = backends.use_gsettings || backends.use_kde || backends.use_xfconf || backends.use_nm;
  bool desktop_success = (backends.use_gsettings && results.gsettings_applied) ||
                         (backends.use_kde && results.kde_applied) ||
                         (backends.use_xfconf && results.xfce_applied) ||
                         (backends.use_nm && results.nm_applied);

  if (attempted_desktop && !desktop_success) {
    defyx_core::LogMessage("ProxyManager: desktop-specific proxy settings were not updated; environment variables applied only");
  } else {
    if (backends.use_gsettings && !results.gsettings_applied) {
      defyx_core::LogMessage("ProxyManager: gsettings schemas not available or failed to update");
    }
    if (backends.use_xfconf && !results.xfce_applied) {
      defyx_core::LogMessage("ProxyManager: XFCE proxy settings not applied");
    }
    if (backends.use_kde && !results.kde_applied) {
      defyx_core::LogMessage("ProxyManager: KDE proxy settings not applied");
    }
    if (backends.use_nm && !results.nm_applied) {
      defyx_core::LogMessage("ProxyManager: NetworkManager proxy settings not applied");
    }
  }
  return true;
}

void ResetSystemProxy() {
  std::lock_guard<std::mutex> lock(g_mutex);
  EnsureSnapshotPath();
  if (!g_applied && !std::filesystem::exists(g_snapshot_path)) {
    return;
  }

  if (!g_applied) {
    // Attempt to load snapshot from disk if available.
    Snapshot snapshot_from_disk;
    if (!LoadSnapshotFromDisk(&snapshot_from_disk)) {
      return;
    }
    g_snapshot = snapshot_from_disk;
  }

  RestoreAll();
  g_applied = false;
  ClearSnapshotFile();
  defyx_core::LogMessage("ProxyManager: restored previous proxy configuration");
}

void RestorePendingSnapshot() {
  std::lock_guard<std::mutex> lock(g_mutex);
  EnsureSnapshotPath();
  Snapshot snapshot_from_disk;
  if (!LoadSnapshotFromDisk(&snapshot_from_disk)) {
    return;
  }
  g_snapshot = snapshot_from_disk;
  g_applied = true;
  RestoreAll();
  g_applied = false;
  ClearSnapshotFile();
  defyx_core::LogMessage("ProxyManager: restored snapshot from previous session");
}

}  // namespace proxy
