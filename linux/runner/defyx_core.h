#pragma once

#include <string>
#include <functional>

namespace defyx_core {
// Simple logger to help with debugging native code. Writes to a log file next
// to the executable.
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
void SetConnectionMethod(const std::string& method);
bool IsTunnelRunning();

// Shared library callback and logging setup
void EnableVerboseLogs(bool enable);
void RegisterProgressHandler(std::function<void(std::string)> handler);

// Attempts to load the libDXcore.so from the given path. If path is empty, tries
// to locate libDXcore.so next to the running executable or in application folder.
// Returns true if the shared library was loaded and entrypoints found.
bool LoadCoreDll(const std::string& dllPath = "");
void UnloadCoreDll();
} // namespace defyx_core