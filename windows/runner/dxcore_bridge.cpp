#include "dxcore_bridge.h"

#include <ShlObj.h>
#include <filesystem>

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
  // ok &= load(pSetConnectionMethod_, "WinSetConnectionMethod");
  ok &= load(pFreeString_, "WinFreeString");
  ok &= load(pSetSystemProxy_, "WinSetSystemProxy");
  ok &= load(pResetSystemProxy_, "WinResetSystemProxy");

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
                          const bool deepScan) {
  if (pStartVPN_) pStartVPN_(cache_dir.c_str(), flow_line.c_str(), pattern.c_str(), deepScan);
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

// void DXCoreBridge::SetConnectionMethod(const std::string& method) {
//   if (pSetConnectionMethod_) pSetConnectionMethod_(method.c_str());
// }

int DXCoreBridge::SetSystemProxy() {
  return pSetSystemProxy_ ? pSetSystemProxy_() : 0;
}

int DXCoreBridge::ResetSystemProxy() {
  return pResetSystemProxy_ ? pResetSystemProxy_() : 0;
}

