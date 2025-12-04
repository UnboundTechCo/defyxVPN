#pragma once

#include <windows.h>
#include <string>

class RegistryManager {
 public:
  RegistryManager();
  ~RegistryManager();

  // Launch on startup registry operations
  bool IsLaunchOnStartupEnabled() const;
  bool SetLaunchOnStartup(bool enable);

  // Application preferences registry operations
  bool GetAutoConnect() const;
  bool SetAutoConnect(bool value);

  bool GetStartMinimized() const;
  bool SetStartMinimized(bool value);

  bool GetForceClose() const;
  bool SetForceClose(bool value);

  bool GetSoundEffect() const;
  bool SetSoundEffect(bool value);

 private:
  static const wchar_t* kAppName;
  static const wchar_t* kStartupRegPath;
  static const wchar_t* kPreferencesRegPath;
};

