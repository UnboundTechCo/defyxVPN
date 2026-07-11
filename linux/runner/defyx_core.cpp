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
#include <openssl/hmac.h>
#include <openssl/evp.h>
#include "linux_key_generated.h"

extern "C" {
typedef int (*dx_start_vpn_fn)(const char* cacheDir, const char* flowLine, const char* pattern, int deepScan, int healthCheck);
typedef int (*dx_stop_vpn_fn)();
typedef void (*dx_start_t2s_fn)(long long fd, const char* addr);
typedef void (*dx_stop_t2s_fn)();
typedef void (*dx_stop_fn)();
typedef long long (*dx_measure_ping_fn)();
typedef char* (*dx_get_flag_fn)();
typedef char* (*dx_get_flowline_fn)(int);
typedef char* (*dx_get_cached_flowline_fn)();
typedef char* (*dx_decode_verify_flowline_fn)(const char*);
typedef char* (*dx_get_vpn_status_fn)();
typedef void (*dx_set_asn_name_fn)();
typedef void (*dx_set_timezone_fn)(float);
typedef void (*dx_set_progress_callback_fn)(void (*)(char*));
typedef void (*dx_set_verbose_logging_fn)(int);
typedef void (*dx_free_string_fn)(char*);
typedef void (*dx_set_connection_method_fn)(const char*);
typedef void (*dx_set_cache_dir_fn)(const char*);
typedef int (*dx_is_tunnel_running_fn)();
typedef char* (*dx_request_handshake_fn)(char*, char*);
typedef char* (*dx_complete_handshake_fn)(char*);
}

static void* g_dx_dll = nullptr;
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
static dx_get_cached_flowline_fn g_get_cached_flowline = nullptr;
static dx_decode_verify_flowline_fn g_decode_verify_flowline = nullptr;
static dx_get_vpn_status_fn g_get_vpn_status = nullptr;
static dx_set_progress_callback_fn g_set_progress_cb = nullptr;
static dx_set_verbose_logging_fn g_set_verbose = nullptr;
static dx_free_string_fn g_free_string = nullptr;
static dx_set_connection_method_fn g_set_connection_method = nullptr;
static dx_set_cache_dir_fn g_set_cache_dir = nullptr;
static dx_is_tunnel_running_fn g_is_tunnel_running = nullptr;
static dx_request_handshake_fn g_request_handshake = nullptr;
static dx_complete_handshake_fn g_complete_handshake = nullptr;

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
  // Logging disabled for release builds.
  // Call sites are kept intact but produce no file output.
  (void)msg;
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
    std::string full = exeDir + "libdxcore_amd64.so";
    dll = dlopen(full.c_str(), RTLD_LAZY);
    if (!dll) {
      const char* err = dlerror();
      defyx_core::LogMessage("dlopen failed for exe-dir path '" + full + "' err=" + (err ? std::string(err) : "unknown"));
    } else {
      defyx_core::LogMessage("Loaded libdxcore_amd64.so from exe dir: " + full);
    }
  }

  // 1b) If not in exe dir root, look in lib/ next to the executable (Flutter bundle layout)
  if (!dll && !exeDir.empty()) {
    std::string nested = exeDir + "lib/libdxcore_amd64.so";
    dll = dlopen(nested.c_str(), RTLD_LAZY);
    if (!dll) {
      const char* err = dlerror();
      defyx_core::LogMessage("dlopen failed for lib-dir path '" + nested + "' err=" + (err ? std::string(err) : "unknown"));
    } else {
      defyx_core::LogMessage("Loaded libdxcore_amd64.so from lib dir: " + nested);
    }
  }

  // 2) If caller provided a non-empty path and we didn't load yet, try it explicitly
  if (!dll && !path.empty()) {
    dll = dlopen(path.c_str(), RTLD_LAZY);
    if (!dll) {
      const char* err = dlerror();
      defyx_core::LogMessage("dlopen failed for provided path '" + path + "' err=" + (err ? std::string(err) : "unknown"));
    } else {
      defyx_core::LogMessage("Loaded libdxcore_amd64.so from provided path: " + path);
    }
  }

  // 3) As a last resort, attempt to load libdxcore_amd64.so using the default search path
  if (!dll) {
    dll = dlopen("libdxcore_amd64.so", RTLD_LAZY);
    if (!dll) {
      const char* err = dlerror();
      defyx_core::LogMessage("Final dlopen('libdxcore_amd64.so') failed err=" + (err ? std::string(err) : "unknown"));
      return false;
    } else {
      defyx_core::LogMessage("Loaded libdxcore_amd64.so from default search path");
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
  g_get_cached_flowline = (dx_get_cached_flowline_fn)dlsym(g_dx_dll, "GetCachedFlowLine");
  g_decode_verify_flowline = (dx_decode_verify_flowline_fn)dlsym(g_dx_dll, "DecodeAndVerifyFlowline");
  g_get_vpn_status = (dx_get_vpn_status_fn)dlsym(g_dx_dll, "GetVpnStatus");
  g_set_progress_cb = (dx_set_progress_callback_fn)dlsym(g_dx_dll, "SetProgressCallback");
  g_set_verbose = (dx_set_verbose_logging_fn)dlsym(g_dx_dll, "SetVerboseLogging");
  g_free_string = (dx_free_string_fn)dlsym(g_dx_dll, "FreeString");
  g_set_connection_method = (dx_set_connection_method_fn)dlsym(g_dx_dll, "SetConnectionMethod");
  g_set_cache_dir = (dx_set_cache_dir_fn)dlsym(g_dx_dll, "SetCacheDir");
  g_is_tunnel_running = (dx_is_tunnel_running_fn)dlsym(g_dx_dll, "IsTunnelRunning");
  g_request_handshake = (dx_request_handshake_fn)dlsym(g_dx_dll, "RequestHandshake");
  g_complete_handshake = (dx_complete_handshake_fn)dlsym(g_dx_dll, "CompleteHandshake");

  auto check = [](const char* name, auto fn) {
    if (!fn) {
      const char* err = dlerror();
      std::string errMsg = err ? err : "unknown";
      defyx_core::LogMessage(std::string("Missing export: ") + name + " (dlerror=" + errMsg + ")");
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
  check("GetCachedFlowLine", g_get_cached_flowline);
  check("DecodeAndVerifyFlowline", g_decode_verify_flowline);
  check("GetVpnStatus", g_get_vpn_status);
  check("SetConnectionMethod", g_set_connection_method);
  check("SetCacheDir", g_set_cache_dir);
  check("IsTunnelRunning", g_is_tunnel_running);
  defyx_core::LogMessage("libdxcore_amd64.so loaded and symbol lookup completed");

  return true;
}

void UnloadCoreDll() {
  std::lock_guard<std::mutex> lock(g_dx_mutex);
  if (g_dx_dll) {
    defyx_core::LogMessage("Unloading libdxcore_amd64.so");
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
    g_get_cached_flowline = nullptr;
    g_get_vpn_status = nullptr;
    g_set_progress_cb = nullptr;
    g_set_verbose = nullptr;
    g_free_string = nullptr;
  g_set_connection_method = nullptr;
  g_is_tunnel_running = nullptr;
  g_request_handshake = nullptr;
  g_complete_handshake = nullptr;

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

bool StartVPN(const std::string& cacheDir, const std::string& flowLine, const std::string& pattern, bool deepScan, bool healthCheck) {
  try {
    defyx_core::LogMessage("StartVPN called cacheDir='" + cacheDir + "' pattern='" + pattern + "' deepScan=" + (deepScan?"1":"0") + " healthCheck=" + (healthCheck?"1":"0"));
    if (!g_dx_dll) LoadCoreDll("");
    if (g_start_vpn) {
      int r = g_start_vpn(cacheDir.c_str(), flowLine.c_str(), pattern.c_str(), deepScan ? 1 : 0, healthCheck ? 1 : 0);
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
      std::string result;
      if (flag && flag[0] != '\0') {
        result = std::string(flag);
      } else {
        result = "xx";
      }
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

std::string GetFlowLine(bool isTest) {
  try {
    defyx_core::LogMessage("GetFlowLine called isTest=" + std::to_string(isTest));
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_flowline) {
      char* line = g_get_flowline(isTest ? 1 : 0);
      std::string result;
      if (line && line[0] != '\0') {
        result = std::string(line);
      } else {
        result = "default";
      }
      if (g_free_string && line) g_free_string(line);
      return result;
    }
  } catch (...) {}
  return "default";
}

std::string GetCachedFlowLine() {
  try {
    defyx_core::LogMessage("GetCachedFlowLine called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_cached_flowline) {
      char* line = g_get_cached_flowline();
      std::string result;
      if (line && line[0] != '\0') {
        result = std::string(line);
      }
      if (g_free_string && line) g_free_string(line);
      return result;
    }
  } catch (...) {}
  return "";
}

std::string DecodeAndVerifyFlowline(const std::string& flowLine) {
  try {
    defyx_core::LogMessage("DecodeAndVerifyFlowline called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_decode_verify_flowline) {
      char* decoded = g_decode_verify_flowline(flowLine.c_str());
      std::string result;
      if (decoded && decoded[0] != '\0') {
        result = std::string(decoded);
      }
      if (g_free_string && decoded) g_free_string(decoded);
      return result;
    }
  } catch (...) {}
  return "";
}

std::string GetVpnStatus() {
  try {
    defyx_core::LogMessage("GetVpnStatus called");
    if (!g_dx_dll) LoadCoreDll("");
    if (g_get_vpn_status) {
      char* status = g_get_vpn_status();
      std::string result;
      if (status && status[0] != '\0') {
        result = std::string(status);
      } else {
        result = "disconnected";
      }
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

void SetCacheDir(const std::string& cacheDir) {
  try {
    defyx_core::LogMessage("SetCacheDir called cacheDir=" + cacheDir);
    
    // Create directory if it doesn't exist
    std::error_code ec;
    std::filesystem::create_directories(cacheDir, ec);
    if (ec) {
      defyx_core::LogMessage("Failed to create cache directory: " + ec.message());
    } else {
      defyx_core::LogMessage("Created cache directory");
    }
    
    if (!g_dx_dll) LoadCoreDll("");
    if (g_set_cache_dir) {
      g_set_cache_dir(cacheDir.c_str());
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

// --- Gateway handshake helpers (file-scope, not exported) --------------------

static std::string GatewayHexEncode(const std::vector<uint8_t>& data) {
  static const char kHex[] = "0123456789abcdef";
  std::string out;
  out.reserve(data.size() * 2);
  for (uint8_t b : data) {
    out.push_back(kHex[b >> 4]);
    out.push_back(kHex[b & 0xf]);
  }
  return out;
}

static bool GatewayHexDecode(const std::string& hex, std::vector<uint8_t>& out) {
  if (hex.size() % 2 != 0) return false;
  out.resize(hex.size() / 2);
  for (size_t i = 0; i < out.size(); ++i) {
    auto val = [](char c) -> int {
      if (c >= '0' && c <= '9') return c - '0';
      if (c >= 'a' && c <= 'f') return c - 'a' + 10;
      if (c >= 'A' && c <= 'F') return c - 'A' + 10;
      return -1;
    };
    int hi = val(hex[i * 2]), lo = val(hex[i * 2 + 1]);
    if (hi < 0 || lo < 0) return false;
    out[i] = static_cast<uint8_t>((hi << 4) | lo);
  }
  return true;
}

static std::vector<uint8_t> GatewayHmacSha256(
    const std::vector<uint8_t>& key, const std::vector<uint8_t>& message) {
  unsigned char result[32];
  unsigned int len = 32;
  HMAC(EVP_sha256(), key.data(), static_cast<int>(key.size()),
       message.data(), message.size(), result, &len);
  return std::vector<uint8_t>(result, result + 32);
}

static bool GatewayGenRandom32(std::vector<uint8_t>& out) {
  out.resize(32);
  std::ifstream urandom("/dev/urandom", std::ios::binary);
  if (!urandom) return false;
  urandom.read(reinterpret_cast<char*>(out.data()), 32);
  return urandom.good() && urandom.gcount() == 32;
}

bool defyx_core::PerformGatewayHandshake() {
  if (!g_dx_dll) LoadCoreDll("");
  if (!g_request_handshake || !g_complete_handshake) return false;

  // Step 1: generate 32 random bytes for the app side
  std::vector<uint8_t> app_random;
  if (!GatewayGenRandom32(app_random)) return false;
  std::string app_random_hex = GatewayHexEncode(app_random);

  // Step 2: request handshake — DLL returns hex-encoded 32-byte core random
  char* kernel_cstr = g_request_handshake(
      const_cast<char*>("1"),
      const_cast<char*>(app_random_hex.c_str()));
  if (!kernel_cstr) return false;
  std::string kernel_hex(kernel_cstr);
  if (g_free_string) g_free_string(kernel_cstr);
  if (kernel_hex.size() != 64) return false;

  std::vector<uint8_t> core_random;
  if (!GatewayHexDecode(kernel_hex, core_random) || core_random.size() != 32)
    return false;

  // Step 3: HMAC-SHA256(key=appRandom||coreRandom, message=embeddedKey)
  const char* embedded = kLinuxGatewayKey;
  std::vector<uint8_t> embedded_bytes(embedded, embedded + strlen(embedded));

  std::vector<uint8_t> client_key;
  client_key.insert(client_key.end(), app_random.begin(), app_random.end());
  client_key.insert(client_key.end(), core_random.begin(), core_random.end());
  std::string client_hash_hex = GatewayHexEncode(GatewayHmacSha256(client_key, embedded_bytes));

  // Step 4: complete handshake — DLL returns its hex-encoded HMAC
  char* server_cstr = g_complete_handshake(
      const_cast<char*>(client_hash_hex.c_str()));
  if (!server_cstr) return false;
  std::string server_hex(server_cstr);
  if (g_free_string) g_free_string(server_cstr);
  if (server_hex.size() != 64) return false;

  std::vector<uint8_t> server_hash;
  if (!GatewayHexDecode(server_hex, server_hash)) return false;

  // Step 5: verify — HMAC-SHA256(key=coreRandom||appRandom, message=embeddedKey)
  std::vector<uint8_t> verify_key;
  verify_key.insert(verify_key.end(), core_random.begin(), core_random.end());
  verify_key.insert(verify_key.end(), app_random.begin(), app_random.end());
  std::vector<uint8_t> expected = GatewayHmacSha256(verify_key, embedded_bytes);
  return server_hash == expected;
}

} // namespace defyx_core