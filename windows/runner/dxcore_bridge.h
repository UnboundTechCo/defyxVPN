#pragma once

#include <functional>
#include <memory>
#include <string>
#include <windows.h>

class DXCoreBridge {
 public:
  DXCoreBridge();
  ~DXCoreBridge();

  bool Load();
  void Unload();

  // Register progress callback; will be called from DXcore threads.
  void SetProgressCallback(std::function<void(const std::string&)> cb);

  // Wrapper APIs
  int Stop();
  int MeasurePing();
  std::string GetFlag();
  void StartVPN(const std::string& cache_dir, const std::string& flow_line,
                const std::string& pattern, const bool deepScan);
  int StopVPN();
  void SetAsnName();
  int SetTimeZone(float tz);
  std::string GetFlowLine(bool is_test);
  std::string GetCachedFlowLine();
  void SetConnectionMethod(const std::string& method);
  int SetSystemProxy();
  int ResetSystemProxy();

  bool IsLoaded() const { return lib_ != nullptr; }

 private:
  HMODULE lib_ = nullptr;

  using progress_cb_t = void (*)(const char*);
  using WinSetProgressListener_t = void (*)(progress_cb_t);
  using WinStop_t = int (*)();
  using WinMeasurePing_t = int (*)();
  using WinGetFlag_t = const char* (*)();
  using WinStartVPN_t = void (*)(const char*, const char*, const char*, int);
  using WinStopVPN_t = int (*)();
  using WinSetAsnName_t = void (*)();
  using WinSetTimeZone_t = int (*)(float);
  using WinGetFlowLine_t = const char* (*)(int);
  using WinGetCachedFlowLine_t = const char* (*)();
  // using WinSetConnectionMethod_t = void (*)(const char*);
  using WinFreeString_t = void (*)(char*);
  using WinSetSystemProxy_t = int (*)();
  using WinResetSystemProxy_t = int (*)();

  WinSetProgressListener_t pSetProgress_ = nullptr;
  WinStop_t pStop_ = nullptr;
  WinMeasurePing_t pMeasurePing_ = nullptr;
  WinGetFlag_t pGetFlag_ = nullptr;
  WinStartVPN_t pStartVPN_ = nullptr;
  WinStopVPN_t pStopVPN_ = nullptr;
  WinSetAsnName_t pSetAsnName_ = nullptr;
  WinSetTimeZone_t pSetTimeZone_ = nullptr;
  WinGetFlowLine_t pGetFlowLine_ = nullptr;
  WinGetCachedFlowLine_t pGetCachedFlowLine_ = nullptr;
  // WinSetConnectionMethod_t pSetConnectionMethod_ = nullptr;
  WinFreeString_t pFreeString_ = nullptr;
  WinSetSystemProxy_t pSetSystemProxy_ = nullptr;
  WinResetSystemProxy_t pResetSystemProxy_ = nullptr;

  static void __stdcall ProgressTrampoline(const char* msg);
  static DXCoreBridge* s_instance_;
  std::function<void(const std::string&)> progress_cb_;
};
