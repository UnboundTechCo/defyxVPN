#include "dxcore_bridge.h"

#include <ShlObj.h>
#include <filesystem>
#include <vector>
#include <bcrypt.h>
#include "windows_key_generated.h"

DXCoreBridge* DXCoreBridge::s_instance_ = nullptr;

DXCoreBridge::DXCoreBridge() {}

DXCoreBridge::~DXCoreBridge() { Unload(); }

void DXCoreBridge::Unload() {
  if (lib_) {
    FreeLibrary(lib_);
    lib_ = nullptr;
  }
}

static std::wstring GetExeDir() {
  wchar_t path[MAX_PATH] = {0};
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::filesystem::path p(path);
  return p.parent_path().wstring();
}

bool DXCoreBridge::Load() {
  if (lib_) return true;

  std::wstring dir = GetExeDir();
  std::wstring dll_path = dir + L"\\DXcore.dll";
  lib_ = LoadLibraryW(dll_path.c_str());
  if (!lib_) {
    // Try alongside data/ or working dir fallbacks
    lib_ = LoadLibraryW(L"DXcore.dll");
  }
  if (!lib_) return false;

  auto load = [&](auto& fn, const char* name) {
    fn = reinterpret_cast<std::remove_reference_t<decltype(fn)>>(GetProcAddress(lib_, name));
    return fn != nullptr;
  };

  bool ok = true;
  ok &= load(pSetProgress_, "WinSetProgressListener");
  ok &= load(pStop_, "WinStop");
  ok &= load(pMeasurePing_, "WinMeasurePing");
  ok &= load(pGetFlag_, "WinGetFlag");
  ok &= load(pStartVPN_, "WinStartVPN");
  ok &= load(pStopVPN_, "WinStopVPN");
  ok &= load(pSetAsnName_, "WinSetAsnName");
  ok &= load(pSetTimeZone_, "WinSetTimeZone");
  ok &= load(pGetFlowLine_, "WinGetFlowLine");
  ok &= load(pGetCachedFlowLine_, "WinGetCachedFlowLine");
  ok &= load(pDecodeAndVerifyFlowline_, "WinDecodeAndVerifyFlowline");
  ok &= load(pSetCacheDir_, "WinSetCacheDir");
  // ok &= load(pSetConnectionMethod_, "WinSetConnectionMethod");
  ok &= load(pFreeString_, "WinFreeString");
  ok &= load(pSetSystemProxy_, "WinSetSystemProxy");
  ok &= load(pResetSystemProxy_, "WinResetSystemProxy");
  // Handshake functions are optional — don't fail Load() if absent
  load(pRequestHandshake_, "WinRequestHandshake");
  load(pCompleteHandshake_, "WinCompleteHandshake");

  if (!ok) {
    Unload();
    return false;
  }

  s_instance_ = this;
  return true;
}

void DXCoreBridge::SetProgressCallback(
    std::function<void(const std::string&)> cb) {
  progress_cb_ = std::move(cb);
  if (pSetProgress_) {
    pSetProgress_(&DXCoreBridge::ProgressTrampoline);
  }
}

void DXCoreBridge::ProgressTrampoline(const char* msg) {
  if (s_instance_ && s_instance_->progress_cb_) {
    s_instance_->progress_cb_(msg ? std::string(msg) : std::string());
  }
}

int DXCoreBridge::Stop() { return pStop_ ? pStop_() : 0; }

int DXCoreBridge::MeasurePing() { return pMeasurePing_ ? pMeasurePing_() : 0; }

std::string DXCoreBridge::GetFlag() {
  if (!pGetFlag_) return {};
  const char* s = pGetFlag_();
  std::string out = s ? std::string(s) : std::string();
  if (s && pFreeString_) pFreeString_(const_cast<char*>(s));
  return out;
}

void DXCoreBridge::StartVPN(const std::string& cache_dir,
                            const std::string& flow_line,
                            const std::string& pattern,
                            const bool deepScan,
                            const bool healthCheck) {
  if (pStartVPN_) pStartVPN_(cache_dir.c_str(), flow_line.c_str(), pattern.c_str(), deepScan, healthCheck);
}

int DXCoreBridge::StopVPN() { return 
  pStopVPN_ ? pStopVPN_() : 0; }

void DXCoreBridge::SetAsnName() {
  if (pSetAsnName_) pSetAsnName_();
}

int DXCoreBridge::SetTimeZone(float tz) {
  return pSetTimeZone_ ? pSetTimeZone_(tz) : 0;
}

std::string DXCoreBridge::GetFlowLine(bool is_test) {
  if (!pGetFlowLine_) return {};
  const char* s = pGetFlowLine_(is_test ? 1 : 0);
  std::string out = s ? std::string(s) : std::string();
  if (s && pFreeString_) pFreeString_(const_cast<char*>(s));
  return out;
}

std::string DXCoreBridge::GetCachedFlowLine() {
  if (!pGetCachedFlowLine_) return {};
  const char* s = pGetCachedFlowLine_();
  std::string out = s ? std::string(s) : std::string();
  if (s && pFreeString_) pFreeString_(const_cast<char*>(s));
  return out;
}

std::string DXCoreBridge::DecodeAndVerifyFlowline(const std::string& flow_line) {
  if (!pDecodeAndVerifyFlowline_) return {};
  const char* s = pDecodeAndVerifyFlowline_(flow_line.c_str());
  std::string out = s ? std::string(s) : std::string();
  if (s && pFreeString_) pFreeString_(const_cast<char*>(s));
  return out;
}

void DXCoreBridge::SetCacheDir(const std::string& cache_dir) {
  // Create directory if it doesn't exist
  try {
    std::filesystem::create_directories(cache_dir);
  } catch (const std::exception& e) {
    // Log error but continue
    (void)e;
  }
  
  if (pSetCacheDir_) pSetCacheDir_(cache_dir.c_str());
}

// void DXCoreBridge::SetConnectionMethod(const std::string& method) {
//   if (pSetConnectionMethod_) pSetConnectionMethod_(method.c_str());
// }

int DXCoreBridge::SetSystemProxy() {
  return pSetSystemProxy_ ? pSetSystemProxy_() : 0;
}

int DXCoreBridge::ResetSystemProxy() {
  return pResetSystemProxy_ ? pResetSystemProxy_() : 0;
}

// ---------------------------------------------------------------------------
// Gateway handshake helpers
// ---------------------------------------------------------------------------

namespace {

// Hex-encode bytes to a lowercase string.
std::string GatewayHexEncode(const std::vector<uint8_t>& bytes) {
  static const char kHex[] = "0123456789abcdef";
  std::string out;
  out.reserve(bytes.size() * 2);
  for (uint8_t b : bytes) { out += kHex[b >> 4]; out += kHex[b & 0x0F]; }
  return out;
}

// Hex-decode a hex string to bytes; returns empty on invalid input.
std::vector<uint8_t> GatewayHexDecode(const std::string& hex) {
  if (hex.size() % 2 != 0) return {};
  std::vector<uint8_t> out;
  out.reserve(hex.size() / 2);
  auto hexval = [](char c) -> int {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
  };
  for (size_t i = 0; i < hex.size(); i += 2) {
    int hi = hexval(hex[i]), lo = hexval(hex[i + 1]);
    if (hi < 0 || lo < 0) return {};
    out.push_back(static_cast<uint8_t>((hi << 4) | lo));
  }
  return out;
}

// HMAC-SHA256(hmac_key, message) — returns raw 32-byte digest.
// Mirrors Go: hmac.New(sha256.New, hmac_key); h.Write(message); h.Sum(nil)
std::vector<uint8_t> GatewayHmacSha256(const std::vector<uint8_t>& hmac_key,
                                        const std::vector<uint8_t>& message) {
  BCRYPT_ALG_HANDLE hAlg = nullptr;
  NTSTATUS status = BCryptOpenAlgorithmProvider(
      &hAlg, BCRYPT_SHA256_ALGORITHM, nullptr, BCRYPT_ALG_HANDLE_HMAC_FLAG);
  if (!BCRYPT_SUCCESS(status)) return {};

  DWORD hash_len = 0, result_size = 0;
  status = BCryptGetProperty(hAlg, BCRYPT_HASH_LENGTH,
                              reinterpret_cast<PUCHAR>(&hash_len),
                              sizeof(hash_len), &result_size, 0);
  if (!BCRYPT_SUCCESS(status)) { BCryptCloseAlgorithmProvider(hAlg, 0); return {}; }

  BCRYPT_HASH_HANDLE hHash = nullptr;
  status = BCryptCreateHash(
      hAlg, &hHash, nullptr, 0,
      const_cast<PUCHAR>(hmac_key.data()),
      static_cast<ULONG>(hmac_key.size()), 0);
  if (!BCRYPT_SUCCESS(status)) { BCryptCloseAlgorithmProvider(hAlg, 0); return {}; }

  status = BCryptHashData(
      hHash,
      const_cast<PUCHAR>(message.data()),
      static_cast<ULONG>(message.size()), 0);
  if (!BCRYPT_SUCCESS(status)) {
    BCryptDestroyHash(hHash); BCryptCloseAlgorithmProvider(hAlg, 0); return {};
  }

  std::vector<uint8_t> hash(hash_len);
  status = BCryptFinishHash(hHash, hash.data(), hash_len, 0);
  BCryptDestroyHash(hHash);
  BCryptCloseAlgorithmProvider(hAlg, 0);
  if (!BCRYPT_SUCCESS(status)) return {};
  return hash;
}

// Generate a cryptographically random 32-character alphanumeric string.
std::string GatewayGenRandom32() {
  static const char kAlpha[] =
      "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  static const int kLen = sizeof(kAlpha) - 1;

  BYTE buf[32] = {};
  BCryptGenRandom(nullptr, buf, sizeof(buf), BCRYPT_USE_SYSTEM_PREFERRED_RNG);

  std::string out;
  out.reserve(32);
  for (int i = 0; i < 32; ++i) {
    out += kAlpha[buf[i] % kLen];
  }
  return out;
}

}  // namespace

bool DXCoreBridge::PerformGatewayHandshake() {
  if (!pRequestHandshake_ || !pCompleteHandshake_) return false;

  // Embedded key: raw ASCII bytes of the (whitespace-stripped) base64 string.
  // Matches Go's []byte(GATEWAY_KEY) — the string itself, not base64-decoded.
  const std::vector<uint8_t> embedded_key(
      reinterpret_cast<const uint8_t*>(kWindowsGatewayKey),
      reinterpret_cast<const uint8_t*>(kWindowsGatewayKey) + strlen(kWindowsGatewayKey));
  if (embedded_key.empty()) return false;

  // Step 1 — 32-char alphanumeric app random (32 ASCII bytes, no nulls).
  const std::string app_random_str = GatewayGenRandom32();
  const std::vector<uint8_t> app_random_bytes(
      app_random_str.begin(), app_random_str.end());

  // Step 2 — requestHandshake; DLL returns hex-encoded 32-byte core random (64 hex chars).
  std::string ver("1"), app_copy(app_random_str);
  char* kernel_hex_raw = pRequestHandshake_(ver.data(), app_copy.data());
  if (!kernel_hex_raw) return false;
  const std::string kernel_hex(kernel_hex_raw);
  if (pFreeString_) pFreeString_(kernel_hex_raw);
  if (kernel_hex.size() != 64) return false;

  const std::vector<uint8_t> core_random = GatewayHexDecode(kernel_hex);
  if (core_random.size() != 32) return false;

  // Step 3 — clientHash = HMAC-SHA256(hmac_key=appRandom||coreRandom, message=embeddedKey)
  // Matches Go: hmac.New(sha256.New, append(clientRandom, coreRandom...)); h.Write(gateway.key)
  std::vector<uint8_t> hmac_key_client;
  hmac_key_client.insert(hmac_key_client.end(),
                          app_random_bytes.begin(), app_random_bytes.end());
  hmac_key_client.insert(hmac_key_client.end(),
                          core_random.begin(), core_random.end());
  const auto client_hash = GatewayHmacSha256(hmac_key_client, embedded_key);
  if (client_hash.empty()) return false;

  // Step 4 — completeHandshake; DLL receives hex clientHash, returns hex serverHash.
  std::string client_hash_hex = GatewayHexEncode(client_hash);
  std::string ch_copy(client_hash_hex);
  char* server_hex_raw = pCompleteHandshake_(ch_copy.data());
  if (!server_hex_raw) return false;
  const std::string server_hex(server_hex_raw);
  if (pFreeString_) pFreeString_(server_hex_raw);
  if (server_hex.size() != 64) return false;

  const std::vector<uint8_t> server_hash = GatewayHexDecode(server_hex);
  if (server_hash.size() != 32) return false;

  // Step 5 — verify: expected = HMAC-SHA256(hmac_key=coreRandom||appRandom, message=embeddedKey)
  // Matches Go: hmac.New(sha256.New, append(coreRandom, clientRandom...)); h.Write(gateway.key)
  std::vector<uint8_t> hmac_key_server;
  hmac_key_server.insert(hmac_key_server.end(),
                          core_random.begin(), core_random.end());
  hmac_key_server.insert(hmac_key_server.end(),
                          app_random_bytes.begin(), app_random_bytes.end());
  const auto expected_hash = GatewayHmacSha256(hmac_key_server, embedded_key);

  return !expected_hash.empty() && server_hash == expected_hash;
}

