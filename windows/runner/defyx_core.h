
#pragma once

#include <string>
#include <functional>

#include <windows.h>
namespace defyx_core {
// Simple logger to help with debugging native code. Writes to a log file next
// to the executable and to the debugger output window (OutputDebugString).
void LogMessage(const std::string& msg);

bool StartVPN(const std::string& cacheDir, const std::string& flowLine, const std::string& pattern);
bool StopVPN();
void StartTun2Socks(long long fd, const std::string& addr);
void StopTun2Socks();
void Stop();
long long MeasurePing();
std::string GetFlag();
void SetAsnName();
void SetTimeZone(float tz);
std::string GetFlowLine();
std::string GetVpnStatus();

// DLL callback and logging setup
void EnableVerboseLogs(bool enable);
void RegisterProgressHandler(std::function<void(std::string)> handler);

// Attempts to load the DXcore.dll from the given path. If path is empty, tries
// to locate DXcore.dll next to the running executable or in application folder.
// Returns true if the DLL was loaded and entrypoints found.
bool LoadCoreDll(const std::wstring& dllPath = L"");
void UnloadCoreDll();
} // namespace defyx_core
