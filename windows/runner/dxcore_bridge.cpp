#include "dxcore_bridge.h"

#include <ShlObj.h>
#include <filesystem>
#include <random>
#include <vector>
#include <bcrypt.h>
#include <wincrypt.h>
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

// Build key bytes from the embedded key string.
// Uses the raw ASCII bytes of the (whitespace-stripped) base64 string,
// which matches the Go-side key derivation.
std::vector<uint8_t> GatewayKeyBytes(const char* key_str) {
  if (!key_str || key_str[0] == '\0') return {};
  const size_t len = strlen(key_str);
  return std::vector<uint8_t>(
      reinterpret_cast<const uint8_t*>(key_str),
      reinterpret_cast<const uint8_t*>(key_str) + len);
}

// HMAC-SHA256 of `message` using `key_bytes`; returns raw 32-byte digest.
std::vector<uint8_t> GatewayHmacSha256Raw(const std::vector<uint8_t>& key_bytes,
                                           const std::string& message) {
  if (key_bytes.empty()) return {};

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
      const_cast<PUCHAR>(key_bytes.data()),
      static_cast<ULONG>(key_bytes.size()), 0);
  if (!BCRYPT_SUCCESS(status)) { BCryptCloseAlgorithmProvider(hAlg, 0); return {}; }

  status = BCryptHashData(
      hHash,
      reinterpret_cast<PUCHAR>(const_cast<char*>(message.data())),
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

// Encode raw bytes as lowercase hex string.
std::string GatewayToHex(const std::vector<uint8_t>& bytes) {
  static const char kHex[] = "0123456789abcdef";
  std::string hex;
  hex.reserve(bytes.size() * 2);
  for (uint8_t b : bytes) { hex += kHex[b >> 4]; hex += kHex[b & 0x0F]; }
  return hex;
}

// Base64-encode a byte buffer (no CRLF, no trailing newline).
std::string GatewayBase64Encode(const std::vector<uint8_t>& data) {
  DWORD len = 0;
  CryptBinaryToStringA(data.data(), static_cast<DWORD>(data.size()),
                        CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                        nullptr, &len);
  std::string out(len, '\0');
  CryptBinaryToStringA(data.data(), static_cast<DWORD>(data.size()),
                        CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                        out.data(), &len);
  out.resize(len);
  return out;
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
#define GW_LOG(fmt, ...) \
  do { fprintf(stderr, "[Gateway] " fmt "\n", ##__VA_ARGS__); fflush(stderr); } while(0)

  if (!pRequestHandshake_ || !pCompleteHandshake_) {
    GW_LOG("FAIL: WinRequestHandshake or WinCompleteHandshake not found in DXcore.dll");
    return false;
  }

  // Key: use the raw ASCII bytes of the embedded key string.
  // (The base64 string itself — stripped of whitespace by CMake — is used as
  //  the HMAC key material, matching the Go-side implementation.)
  const std::vector<uint8_t> key = GatewayKeyBytes(kWindowsGatewayKey);
  if (key.empty()) {
    GW_LOG("FAIL: embedded key is empty — WINDOWS_KEY.txt missing at build time");
    return false;
  }
  GW_LOG("key: %zu raw bytes", key.size());

  // Step 1 — app generates random, calls requestHandshake.
  const std::string app_random = GatewayGenRandom32();
  GW_LOG("appRandom(%zu): %s", app_random.size(), app_random.c_str());

  std::string ver("1");
  std::string app_rand_copy(app_random);
  char* kernel_raw = pRequestHandshake_(
      const_cast<char*>(ver.c_str()),
      const_cast<char*>(app_rand_copy.c_str()));
  if (!kernel_raw) {
    GW_LOG("FAIL: WinRequestHandshake returned null");
    return false;
  }
  const std::string kernel_random(kernel_raw);
  if (pFreeString_) pFreeString_(kernel_raw);
  GW_LOG("kernelRandom(%zu): hex=%s", kernel_random.size(),
         GatewayToHex(std::vector<uint8_t>(kernel_random.begin(), kernel_random.end())).c_str());
  if (kernel_random.size() != 32) {
    GW_LOG("FAIL: kernelRandom length is %zu, expected 32", kernel_random.size());
    return false;
  }

  // Step 2 — clientHash = HMAC(key, appRandom[:16] + kernelRandom[16:])
  const std::string client_msg = app_random.substr(0, 16) + kernel_random.substr(16);
  const std::vector<uint8_t> client_raw = GatewayHmacSha256Raw(key, client_msg);
  const std::string client_hash_hex = GatewayToHex(client_raw);
  const std::string client_hash_b64 = GatewayBase64Encode(client_raw);
  GW_LOG("clientHash hex: %s", client_hash_hex.c_str());
  GW_LOG("clientHash b64: %s", client_hash_b64.c_str());
  if (client_raw.empty()) {
    GW_LOG("FAIL: BCrypt HMAC-SHA256 failed");
    return false;
  }

  // Send hex-encoded hash to completeHandshake.
  // If serverHash remains empty below, try switching to b64 (see comment).
  const std::string client_hash = client_hash_hex;

  // Step 3 — completeHandshake: send clientHash, receive serverHash.
  std::string client_hash_copy(client_hash);
  char* server_raw = pCompleteHandshake_(
      const_cast<char*>(client_hash_copy.c_str()));
  if (!server_raw) {
    GW_LOG("FAIL: WinCompleteHandshake returned null");
    return false;
  }
  const std::string server_hash(server_raw);
  if (pFreeString_) pFreeString_(server_raw);
  GW_LOG("serverHash(%zu): hex=%s", server_hash.size(), server_hash.c_str());
  if (server_hash.empty()) {
    GW_LOG("FAIL: WinCompleteHandshake returned empty — kernel rejected our clientHash");
    GW_LOG("      Check Go source: does completeHandshake expect hex or base64?");
    return false;
  }

  // Step 4 — verify: expectedHash = HMAC(key, kernelRandom[:16] + appRandom[16:])
  const std::string expected_msg = kernel_random.substr(0, 16) + app_random.substr(16);
  const std::vector<uint8_t> expected_raw = GatewayHmacSha256Raw(key, expected_msg);
  const std::string expected_hash = GatewayToHex(expected_raw);
  GW_LOG("expectedHash: %s", expected_hash.c_str());

  const bool ok = !expected_hash.empty() && server_hash == expected_hash;
  GW_LOG("%s", ok ? "OK: handshake verified" : "FAIL: serverHash != expectedHash");
#undef GW_LOG
  return ok;
}

