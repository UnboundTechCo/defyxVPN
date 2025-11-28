#include "defyx_core.h"
#include <chrono>
#include <mutex>
#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>
#include <vector>
#include <dlfcn.h>
#include <unistd.h>
#include <limits.h>

extern "C" {
typedef int (*dx_start_vpn_fn)(const char* cacheDir, const char* flowLine, const char* pattern);
typedef int (*dx_stop_vpn_fn)();
typedef void (*dx_start_t2s_fn)(long long fd, const char* addr);
typedef void (*dx_stop_t2s_fn)();
typedef void (*dx_stop_fn)();
typedef long long (*dx_measure_ping_fn)();
typedef char* (*dx_get_flag_fn)();
typedef char* (*dx_get_flowline_fn)();
typedef char* (*dx_get_vpn_status_fn)();
typedef void (*dx_set_asn_name_fn)();
typedef void (*dx_set_timezone_fn)(float);
typedef void (*dx_set_progress_callback_fn)(void (*)(char*));
typedef void (*dx_set_verbose_logging_fn)(int);
typedef void (*dx_free_string_fn)(char*);
typedef void (*dx_set_connection_method_fn)(const char*);
typedef int (*dx_is_tunnel_running_fn)();
}

static void* g_dx_dll = nullptr;
static std::mutex g_dx_mutex;
static std::mutex g_log_mutex;
static dx_start_vpn_fn g_start_vpn = nullptr;
static dx_stop_vpn_fn g_stop_vpn = nullptr;
static dx_start_t2s_fn g_start_t2s = nullptr;
static dx_stop_t2s_fn g_stop_t2s = nullptr;
static dx_stop_fn g_stop_all = nullptr;
static dx_measure_ping_fn g_measure_ping = nullptr;
static dx_get_flag_fn g_get_flag = nullptr;
static dx_set_asn_name_fn g_set_asn_name = nullptr;
static dx_set_timezone_fn g_set_timezone = nullptr;
static dx_get_flowline_fn g_get_flowline = nullptr;
static dx_get_vpn_status_fn g_get_vpn_status = nullptr;
static dx_set_progress_callback_fn g_set_progress_cb = nullptr;
static dx_set_verbose_logging_fn g_set_verbose = nullptr;
static dx_free_string_fn g_free_string = nullptr;
static dx_set_connection_method_fn g_set_connection_method = nullptr;
static dx_is_tunnel_running_fn g_is_tunnel_running = nullptr;

// Helper: get directory of current executable
static std::string GetExeDir() {
  char exePath[PATH_MAX];
  ssize_t len = readlink("/proc/self/exe", exePath, sizeof(exePath) - 1);
  if (len == -1) return "";
  exePath[len] = '\0';
  std::string path(exePath);
  size_t pos = path.find_last_of("/");
  if (pos == std::string::npos) return "";
  return path.substr(0, pos + 1);
}

// Logger implementation
namespace defyx_core {
void LogMessage(const std::string& msg) {
  // Prefix with timestamp (ms since epoch)
  using namespace std::chrono;
  auto now = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
  std::lock_guard<std::mutex> lock(g_log_mutex);
  std::string exeDir = GetExeDir();
  std::string logPath = exeDir.empty() ? "defyx_linux.log" : (exeDir + "defyx_linux.log");
  std::ofstream ofs;
  ofs.open(logPath, std::ios::app);
  if (ofs.is_open()) {
    ofs << now << " | " << msg << "\n";
    ofs.close();
  }
}
} // namespace defyx_core

static std::function<void(std::string)> g_progress_handler;

static void DxProgressC(char* msg) {
  if (!msg) return;
  std::string s(msg);
  defyx_core::LogMessage("[DX] " + s);
  if (g_progress_handler) g_progress_handler(s);
}

bool LoadCoreDll(const std::string& dllPath) {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) return true;

  std::string path = dllPath;
  void* dll = nullptr;

  // 1) Prefer loading from the exe directory
  std::string exeDir = GetExeDir();
  if (!exeDir.empty()) {
    std::string full = exeDir + "libDXcore.so";
    dll = dlopen(full.c_str(), RTLD_LAZY);
    if (!dll) {
      defyx_core::LogMessage("dlopen failed for exe-dir path '" + full + "' err=" + std::string(dlerror()));
    } else {
      defyx_core::LogMessage("Loaded libDXcore.so from exe dir: " + full);
    }
  }

  // 1b) If not in exe dir root, look in lib/ next to the executable (Flutter bundle layout)
  if (!dll && !exeDir.empty()) {
    std::string nested = exeDir + "lib/libDXcore.so";
    dll = dlopen(nested.c_str(), RTLD_LAZY);
    if (!dll) {
      defyx_core::LogMessage("dlopen failed for lib-dir path '" + nested + "' err=" + std::string(dlerror()));
    } else {
      defyx_core::LogMessage("Loaded libDXcore.so from lib dir: " + nested);
    }
  }

  // 2) If caller provided a non-empty path and we didn't load yet, try it explicitly
  if (!dll && !path.empty()) {
    dll = dlopen(path.c_str(), RTLD_LAZY);
    if (!dll) {
      defyx_core::LogMessage("dlopen failed for provided path '" + path + "' err=" + std::string(dlerror()));
    } else {
      defyx_core::LogMessage("Loaded libDXcore.so from provided path: " + path);
    }
  }

  // 3) As a last resort, attempt to load libDXcore.so using the default search path
  if (!dll) {
    dll = dlopen("libDXcore.so", RTLD_LAZY);
    if (!dll) {
      defyx_core::LogMessage("Final dlopen('libDXcore.so') failed err=" + std::string(dlerror()));
      return false;
    } else {
      defyx_core::LogMessage("Loaded libDXcore.so from default search path");
    }
  }

  g_dx_dll = dll;

  g_start_vpn = (dx_start_vpn_fn)dlsym(g_dx_dll, "StartVPN");
  g_stop_vpn = (dx_stop_vpn_fn)dlsym(g_dx_dll, "StopVPN");
  g_start_t2s = (dx_start_t2s_fn)dlsym(g_dx_dll, "StartTun2Socks");
  g_stop_t2s = (dx_stop_t2s_fn)dlsym(g_dx_dll, "StopTun2Socks");
  g_stop_all = (dx_stop_fn)dlsym(g_dx_dll, "Stop");
  g_measure_ping = (dx_measure_ping_fn)dlsym(g_dx_dll, "MeasurePing");
  g_get_flag = (dx_get_flag_fn)dlsym(g_dx_dll, "GetFlag");
  g_set_asn_name = (dx_set_asn_name_fn)dlsym(g_dx_dll, "SetAsnName");
  g_set_timezone = (dx_set_timezone_fn)dlsym(g_dx_dll, "SetTimeZone");
  g_get_flowline = (dx_get_flowline_fn)dlsym(g_dx_dll, "GetFlowLine");
  g_get_vpn_status = (dx_get_vpn_status_fn)dlsym(g_dx_dll, "GetVpnStatus");
  g_set_progress_cb = (dx_set_progress_callback_fn)dlsym(g_dx_dll, "SetProgressCallback");
  g_set_verbose = (dx_set_verbose_logging_fn)dlsym(g_dx_dll, "SetVerboseLogging");
  g_free_string = (dx_free_string_fn)dlsym(g_dx_dll, "FreeString");
  g_set_connection_method = (dx_set_connection_method_fn)dlsym(g_dx_dll, "SetConnectionMethod");
  g_is_tunnel_running = (dx_is_tunnel_running_fn)dlsym(g_dx_dll, "IsTunnelRunning");

  auto check = [](const char* name, auto fn) {
    if (!fn) {
      defyx_core::LogMessage(std::string("Missing export: ") + name + " (dlerror=" + std::string(dlerror()) + ")");
    }
  };
  check("SetProgressCallback", g_set_progress_cb);
  check("SetVerboseLogging", g_set_verbose);
  check("FreeString", g_free_string);
  check("StartVPN", g_start_vpn);
  check("StopVPN", g_stop_vpn);
  check("StartTun2Socks", g_start_t2s);
  check("StopTun2Socks", g_stop_t2s);
  check("Stop", g_stop_all);
  check("MeasurePing", g_measure_ping);
  check("GetFlag", g_get_flag);
  check("SetAsnName", g_set_asn_name);
  check("SetTimeZone", g_set_timezone);
  check("GetFlowLine", g_get_flowline);
  check("GetVpnStatus", g_get_vpn_status);
  check("SetConnectionMethod", g_set_connection_method);
  check("IsTunnelRunning", g_is_tunnel_running);
  defyx_core::LogMessage("libDXcore.so loaded and symbol lookup completed");

  return true;
}

void UnloadCoreDll() {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) {
    defyx_core::LogMessage("Unloading libDXcore.so");
    g_start_vpn = nullptr;
    g_stop_vpn = nullptr;
    g_start_t2s = nullptr;
    g_stop_t2s = nullptr;
    g_stop_all = nullptr;
    g_measure_ping = nullptr;
    g_get_flag = nullptr;
    g_set_asn_name = nullptr;
    g_set_timezone = nullptr;
    g_get_flowline = nullptr;
    g_get_vpn_status = nullptr;
    g_set_progress_cb = nullptr;
    g_set_verbose = nullptr;
    g_free_string = nullptr;
  g_set_connection_method = nullptr;
  g_is_tunnel_running = nullptr;

    // Clear progress handler
    g_progress_handler = nullptr;

    dlclose(g_dx_dll);
    g_dx_dll = nullptr;
  }
}

namespace defyx_core {
bool LoadCoreDll(const std::string& dllPath) {
  return ::LoadCoreDll(dllPath);
}

void UnloadCoreDll() {
  ::UnloadCoreDll();
}

void EnableVerboseLogs(bool enable) {
  if (g_set_verbose) {
    g_set_verbose(enable ? 1 : 0);
  }
}

void RegisterProgressHandler(std::function<void(std::string)> handler) {
  g_progress_handler = std::move(handler);
  if (g_set_progress_cb) {
    g_set_progress_cb(&DxProgressC);
  }
}
} // namespace defyx_core

namespace defyx_core {

bool StartVPN(const std::string& cacheDir, const std::string& flowLine, const std::string& pattern) {
  try {
    defyx_core::LogMessage("StartVPN called cacheDir='" + cacheDir + "' flowLine='" + flowLine + "' pattern='" + pattern + "'");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_start_vpn) {
      int r = g_start_vpn(cacheDir.c_str(), flowLine.c_str(), pattern.c_str());
      defyx_core::LogMessage(std::string("StartVPN returned ") + (r != 0 ? "true" : "false"));
      return r != 0;
    }
  } catch (...) {}
  (void)cacheDir; (void)flowLine; (void)pattern;
  return true;
}

void StartTun2Socks(long long fd, const std::string& addr) {
  try {
    defyx_core::LogMessage("StartTun2Socks called fd=" + std::to_string(fd) + " addr='" + addr + "'");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_start_t2s) {
      g_start_t2s(fd, addr.c_str());
      return;
    }
  } catch (...) {}
  (void)fd; (void)addr;
}

long long MeasurePing() {
  try {
    defyx_core::LogMessage("MeasurePing called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_measure_ping) {
      auto v = g_measure_ping();
      defyx_core::LogMessage("MeasurePing returned " + std::to_string(v));
      return v;
    }
  } catch (...) {}
  // fallback fake ping
  using namespace std::chrono;
  return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count() % 200;
}

bool StopVPN() {
  try {
    defyx_core::LogMessage("StopVPN called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_stop_vpn) {
      auto r = g_stop_vpn() != 0;
      defyx_core::LogMessage(std::string("StopVPN returned ") + (r ? "true" : "false"));
      return r;
    }
  } catch (...) {}
  return true;
}

void StopTun2Socks() {
  try {
    defyx_core::LogMessage("StopTun2Socks called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_stop_t2s) { g_stop_t2s(); return; }
  } catch (...) {}
}

void Stop() {
  try {
    defyx_core::LogMessage("Stop called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_stop_all) { g_stop_all(); return; }
  } catch (...) {}
}

std::string GetFlag() {
  try {
    defyx_core::LogMessage("GetFlag called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_flag) {
      char* flag = g_get_flag();
      std::string result = flag ? std::string(flag) : std::string();
      if (g_free_string && flag) g_free_string(flag);
      return result;
    }
  } catch (...) {}
  return "xx";
}

void SetAsnName() {
  try {
    defyx_core::LogMessage("SetAsnName called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_set_asn_name) { g_set_asn_name(); return; }
  } catch (...) {}
}

void SetTimeZone(float tz) {
  try {
    defyx_core::LogMessage("SetTimeZone called tz=" + std::to_string(tz));
    if (!g_dx_dll) LoadCoreDll("");
    if (g_set_timezone) { g_set_timezone(tz); return; }
  } catch (...) {}
  (void)tz;
}

std::string GetFlowLine() {
  try {
    defyx_core::LogMessage("GetFlowLine called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_flowline) {
      char* line = g_get_flowline();
      std::string result = line ? std::string(line) : std::string();
      if (g_free_string && line) g_free_string(line);
      return result;
    }
  } catch (...) {}
  return "default";
}

std::string GetVpnStatus() {
  try {
    defyx_core::LogMessage("GetVpnStatus called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_vpn_status) {
      char* status = g_get_vpn_status();
      std::string result = status ? std::string(status) : std::string();
      if (g_free_string && status) g_free_string(status);
      return result;
    }
  } catch (...) {}
  return "disconnected";
}

void SetConnectionMethod(const std::string& method) {
  try {
    defyx_core::LogMessage("SetConnectionMethod called method=" + method);
    if (!g_dx_dll) LoadCoreDll("");
    if (g_set_connection_method) {
      g_set_connection_method(method.c_str());
    }
  } catch (...) {}
}

bool IsTunnelRunning() {
  try {
    defyx_core::LogMessage("IsTunnelRunning called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_is_tunnel_running) {
      bool running = g_is_tunnel_running() != 0;
      defyx_core::LogMessage(std::string("IsTunnelRunning returned ") + (running ? "true" : "false"));
      return running;
    }
  } catch (...) {}
  return false;
}

} // namespace defyx_core