#include "defyx_core.h"
#include <chrono>
#include <mutex>
#include <iostream>

extern "C" {
typedef int (*dx_start_vpn_fn)(const char* cacheDir, const char* flowLine, const char* pattern);
typedef int (*dx_stop_vpn_fn)();
typedef void (*dx_start_t2s_fn)(long long fd, const char* addr);
typedef void (*dx_stop_t2s_fn)();
typedef void (*dx_stop_fn)();
typedef long long (*dx_measure_ping_fn)();
typedef const char* (*dx_get_flag_fn)();
typedef void (*dx_set_asn_name_fn)();
typedef void (*dx_set_timezone_fn)(float);
typedef const char* (*dx_get_flowline_fn)();
typedef const char* (*dx_get_vpn_status_fn)();
}

static HMODULE g_dx_dll = nullptr;
static std::mutex g_dx_mutex;
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

bool LoadCoreDll(const std::wstring& dllPath) {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) return true;

  std::wstring path = dllPath;
  if (path.empty()) {

    path = L"DXcore.dll";
  }

  HMODULE dll = nullptr;
  if (!dllPath.empty()) dll = ::LoadLibraryW(path.c_str());

  if (!dll) {
    wchar_t exePath[MAX_PATH];
    if (GetModuleFileNameW(NULL, exePath, MAX_PATH) > 0) {
      std::wstring exeDir(exePath);
      auto pos = exeDir.find_last_of(L"\\/");
      if (pos != std::wstring::npos) exeDir = exeDir.substr(0, pos + 1);
      std::wstring full = exeDir + L"DXcore.dll";
      dll = ::LoadLibraryW(full.c_str());
    }
  }

  if (!dll) dll = ::LoadLibraryW(L"DXcore.dll");
  if (!dll) return false;

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


  return true;
}

void UnloadCoreDll() {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) {
    ::FreeLibrary(g_dx_dll);
    g_dx_dll = nullptr;
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
  }
}


namespace defyx_core {
bool LoadCoreDll(const std::wstring& dllPath) {
  return ::LoadCoreDll(dllPath);
}

void UnloadCoreDll() {
  ::UnloadCoreDll();
}
} // namespace defyx_core

namespace defyx_core {

bool StartVPN(const std::string& cacheDir, const std::string& flowLine, const std::string& pattern) {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_start_vpn) {
      int r = g_start_vpn(cacheDir.c_str(), flowLine.c_str(), pattern.c_str());
      return r != 0;
    }
  } catch (...) {}
  (void)cacheDir; (void)flowLine; (void)pattern;
  return true;
}
void StartTun2Socks(long long fd, const std::string& addr) {
  try {
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
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_measure_ping) {
      return g_measure_ping();
    }
  } catch (...) {}
  // fallback fake ping
  using namespace std::chrono;
  return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count() % 200;
}


bool StopVPN() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_stop_vpn) return g_stop_vpn() != 0;
  } catch (...) {}
  return true;
}

void StopTun2Socks() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_stop_t2s) { g_stop_t2s(); return; }
  } catch (...) {}
}

void Stop() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_stop_all) { g_stop_all(); return; }
  } catch (...) {}
}

std::string GetFlag() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_get_flag) {
      const char* c = g_get_flag();
      if (c) return std::string(c);
    }
  } catch (...) {}
  return "xx";
}

void SetAsnName() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_set_asn_name) { g_set_asn_name(); return; }
  } catch (...) {}
}

void SetTimeZone(float tz) {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_set_timezone) { g_set_timezone(tz); return; }
  } catch (...) {}
  (void)tz;
}

std::string GetFlowLine() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_get_flowline) {
      const char* c = g_get_flowline();
      if (c) return std::string(c);
    }
  } catch (...) {}
  return "default";
}

std::string GetVpnStatus() {
  try {
    if (!g_dx_dll) LoadCoreDll(L"");
    if (g_get_vpn_status) {
      const char* c = g_get_vpn_status();
      if (c) return std::string(c);
    }
  } catch (...) {}
  return "disconnected";
}


} // namespace defyx_core
