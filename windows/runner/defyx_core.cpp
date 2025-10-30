#include "defyx_core.h"
#include <chrono>
#include <mutex>
#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>
#include <vector>

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
}

static HMODULE g_dx_dll = nullptr;
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

// Helper: get directory of current executable . for debug only 
static std::wstring GetExeDir() {
  wchar_t exePath[MAX_PATH];
  DWORD len = GetModuleFileNameW(NULL, exePath, MAX_PATH);
  if (len == 0) return L"";
  std::wstring path(exePath, exePath + len);
  size_t pos = path.find_last_of(L"\\/");
  if (pos == std::wstring::npos) return L"";
  return path.substr(0, pos + 1);
}

// Helper: wide -> UTF-8
static std::string WideToUtf8(const std::wstring& ws) {
  if (ws.empty()) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), nullptr, 0, nullptr, nullptr);
  if (needed <= 0) return std::string();
  std::string out(needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), out.data(), needed, nullptr, nullptr);
  return out;
}

// Logger implementation . debug only 
namespace defyx_core {
void LogMessage(const std::string& msg) {
  // Prefix with timestamp (ms since epoch)
  using namespace std::chrono;
  auto now = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
  std::lock_guard<std::mutex> lock(g_log_mutex);
  std::wstring exeDir = GetExeDir();
  std::wstring wlogPath = exeDir.empty() ? L"defyx_windows.log" : (exeDir + L"defyx_windows.log");
  std::ofstream ofs;
  ofs.open(std::filesystem::path(wlogPath), std::ios::app);
  if (ofs.is_open()) {
    ofs << now << " | " << msg << "\n";
    ofs.close();
  }
  std::wstring wmsg(msg.begin(), msg.end());
  std::wstring out = L"[defyx] " + wmsg + L"\n";
  OutputDebugStringW(out.c_str());
}
} // namespace defyx_core


static std::function<void(std::string)> g_progress_handler;

static void __stdcall DxProgressC(char* msg) {
  if (!msg) return;
  std::string s(msg);
  defyx_core::LogMessage("[DX] " + s);
  if (g_progress_handler) g_progress_handler(s);
}

bool LoadCoreDll(const std::wstring& dllPath) {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) return true;

  std::wstring path = dllPath;

  // Determine exe directory for safe DLL loading (avoid C:\\Windows\\System32 name collision with dxcore.dll so bitches like wont be able to hijack defyx service )
  wchar_t exePath[MAX_PATH];
  std::wstring exeDir;
  if (GetModuleFileNameW(NULL, exePath, MAX_PATH) > 0) {
    exeDir.assign(exePath);
    auto pos = exeDir.find_last_of(L"\\/");
    if (pos != std::wstring::npos) exeDir = exeDir.substr(0, pos + 1);
  }

  HMODULE dll = nullptr;
  // 1) Prefer loading from the exe directory to avoid picking up the system dxcore.dll. This helps prevent DLL hijacking attacks and ensures the intended DLL is loaded.
  if (!exeDir.empty()) {
    std::wstring full = exeDir + L"DXcore.dll";
    dll = ::LoadLibraryW(full.c_str());
    if (!dll) {
      DWORD err = GetLastError();
      defyx_core::LogMessage("LoadLibrary failed for exe-dir path '" + WideToUtf8(full) + "' err=" + std::to_string(err));
    } else {
      wchar_t dllFullPath[MAX_PATH];
      DWORD pathLen = GetModuleFileNameW(dll, dllFullPath, MAX_PATH);
      if (pathLen > 0) {
        defyx_core::LogMessage("Loaded DXcore.dll from exe dir first: " + WideToUtf8(full) + " -> ACTUAL: " + WideToUtf8(std::wstring(dllFullPath, pathLen)));
      } else {
        defyx_core::LogMessage("Loaded DXcore.dll from exe dir first: " + WideToUtf8(full) + " (couldn't get full path)");
      }
    }
  }

  // 2) If caller provided a non-empty path and we didn't load yet, try it explicitly
  if (!dll && !path.empty()) {
    dll = ::LoadLibraryW(path.c_str());
    if (!dll) {
      DWORD err = GetLastError();
      defyx_core::LogMessage("LoadLibrary failed for provided path '" + WideToUtf8(path) + "' err=" + std::to_string(err));
    } else {
      wchar_t dllFullPath[MAX_PATH];
      DWORD pathLen = GetModuleFileNameW(dll, dllFullPath, MAX_PATH);
      if (pathLen > 0) {
        defyx_core::LogMessage("Loaded DXcore.dll from provided path: " + WideToUtf8(path) + " -> ACTUAL PATH: " + WideToUtf8(std::wstring(dllFullPath, pathLen)));
      } else {
        defyx_core::LogMessage("Loaded DXcore.dll from provided path: " + WideToUtf8(path) + " (couldn't get full path)");
      }
    }
  }

  // 3) As a last resort, attempt to load DXcore.dll using the default search path.
  //    This is not preferred due to potential name collisions with system-wide DLLs.
  //    This fallback is used only if loading from the executable directory and the provided path both fail.
  if (!dll) {
    dll = ::LoadLibraryW(L"DXcore.dll");
    if (!dll) {
      DWORD err = GetLastError();
      defyx_core::LogMessage("Final LoadLibrary('DXcore.dll') failed err=" + std::to_string(err));
      return false;
    } else {
      wchar_t dllFullPath[MAX_PATH];
      DWORD pathLen = GetModuleFileNameW(dll, dllFullPath, MAX_PATH);
      if (pathLen > 0) {
        defyx_core::LogMessage("Loaded DXcore.dll from default search path -> ACTUAL: " + WideToUtf8(std::wstring(dllFullPath, pathLen)));
      } else {
        defyx_core::LogMessage("Loaded DXcore.dll from default search path (couldn't get full path)");
      }
    }
  }


  g_dx_dll = dll;

  g_start_vpn = (dx_start_vpn_fn)::GetProcAddress(g_dx_dll, "StartVPN");
  g_stop_vpn = (dx_stop_vpn_fn)::GetProcAddress(g_dx_dll, "StopVPN");
  g_start_t2s = (dx_start_t2s_fn)::GetProcAddress(g_dx_dll, "StartTun2Socks");
  g_stop_t2s = (dx_stop_t2s_fn)::GetProcAddress(g_dx_dll, "StopTun2Socks");
  g_stop_all = (dx_stop_fn)::GetProcAddress(g_dx_dll, "Stop");
  g_measure_ping = (dx_measure_ping_fn)::GetProcAddress(g_dx_dll, "MeasurePing");
  g_get_flag = (dx_get_flag_fn)::GetProcAddress(g_dx_dll, "GetFlag");
  g_set_asn_name = (dx_set_asn_name_fn)::GetProcAddress(g_dx_dll, "SetAsnName");
  g_set_timezone = (dx_set_timezone_fn)::GetProcAddress(g_dx_dll, "SetTimeZone");
  g_get_flowline = (dx_get_flowline_fn)::GetProcAddress(g_dx_dll, "GetFlowLine");
  g_get_vpn_status = (dx_get_vpn_status_fn)::GetProcAddress(g_dx_dll, "GetVpnStatus");
  g_set_progress_cb = (dx_set_progress_callback_fn)::GetProcAddress(g_dx_dll, "SetProgressCallback");
  g_set_verbose     = (dx_set_verbose_logging_fn)::GetProcAddress(g_dx_dll, "SetVerboseLogging");
  g_free_string     = (dx_free_string_fn)::GetProcAddress(g_dx_dll, "FreeString");

  auto check = [](const char* name, auto fn) { 
    if (!fn) {
      DWORD err = GetLastError();
      defyx_core::LogMessage(std::string("Missing export: ") + name + " (GetLastError=" + std::to_string(err) + ")"); 
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
  defyx_core::LogMessage("DXcore.dll loaded and symbol lookup completed");

  return true;
}

void UnloadCoreDll() {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) {
    defyx_core::LogMessage("Unloading DXcore.dll");
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
    
    // Clear progress handler
    g_progress_handler = nullptr;
    
    ::FreeLibrary(g_dx_dll);
    g_dx_dll = nullptr;
  }
}


namespace defyx_core {
bool LoadCoreDll(const std::wstring& dllPath) {
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
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_stop_t2s) { g_stop_t2s(); return; }
  } catch (...) {}
}

void Stop() {
  try {
    defyx_core::LogMessage("Stop called");
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_stop_all) { g_stop_all(); return; }
  } catch (...) {}
}

std::string GetFlag() {
  try {
    defyx_core::LogMessage("GetFlag called");
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_set_asn_name) { g_set_asn_name(); return; }
  } catch (...) {}
}

void SetTimeZone(float tz) {
  try {
    defyx_core::LogMessage("SetTimeZone called tz=" + std::to_string(tz));
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_set_timezone) { g_set_timezone(tz); return; }
  } catch (...) {}
  (void)tz;
}

std::string GetFlowLine() {
  try {
    defyx_core::LogMessage("GetFlowLine called");
    if (!g_dx_dll) LoadCoreDll(L"");
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
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_get_vpn_status) {
      char* status = g_get_vpn_status();
      std::string result = status ? std::string(status) : std::string();
      if (g_free_string && status) g_free_string(status);
      return result;
    }
  } catch (...) {}
  return "disconnected";
}


} // namespace defyx_core
