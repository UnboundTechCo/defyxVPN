
#pragma once

#include <string>

#include <windows.h>
namespace defyx_core {
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

// Attempts to load the DXcore.dll from the given path. If path is empty, tries
// to locate DXcore.dll next to the running executable or in application folder.
// Returns true if the DLL was loaded and entrypoints found.
bool LoadCoreDll(const std::wstring& dllPath = L"");
void UnloadCoreDll();
} // namespace defyx_core
