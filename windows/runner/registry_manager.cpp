#include "registry_manager.h"

const wchar_t* RegistryManager::kAppName = L"DefyxVPN";
const wchar_t* RegistryManager::kStartupRegPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const wchar_t* RegistryManager::kPreferencesRegPath = L"Software\\DefyxVPN";

RegistryManager::RegistryManager() {}

RegistryManager::~RegistryManager() {}

bool RegistryManager::IsLaunchOnStartupEnabled() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kStartupRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    wchar_t existingPath[MAX_PATH] = {0};
    DWORD bufSize = sizeof(existingPath);
    LONG result = RegQueryValueExW(hKey, kAppName, nullptr, nullptr, (LPBYTE)existingPath, &bufSize);
    RegCloseKey(hKey);
    return result == ERROR_SUCCESS;
  }
  return false;
}

bool RegistryManager::SetLaunchOnStartup(bool enable) {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kStartupRegPath, 0, KEY_SET_VALUE | KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    if (enable) {
      wchar_t exePath[MAX_PATH];
      GetModuleFileNameW(nullptr, exePath, MAX_PATH);
      std::wstring startupCommand = std::wstring(exePath) + L" --startup";
      RegSetValueExW(hKey, kAppName, 0, REG_SZ, (const BYTE*)startupCommand.c_str(),
                     static_cast<DWORD>((startupCommand.length() + 1) * sizeof(wchar_t)));
    } else {
      RegDeleteValueW(hKey, kAppName);
    }
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

bool RegistryManager::GetAutoConnect() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 0;
    DWORD bufSize = sizeof(DWORD);
    LONG result = RegQueryValueExW(hKey, L"AutoConnect", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return result == ERROR_SUCCESS && value != 0;
  }
  return false;
}

bool RegistryManager::SetAutoConnect(bool value) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = value ? 1 : 0;
    RegSetValueExW(hKey, L"AutoConnect", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

bool RegistryManager::GetStartMinimized() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 0;
    DWORD bufSize = sizeof(DWORD);
    LONG result = RegQueryValueExW(hKey, L"StartMinimized", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return result == ERROR_SUCCESS && value != 0;
  }
  return false;
}

bool RegistryManager::SetStartMinimized(bool value) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = value ? 1 : 0;
    RegSetValueExW(hKey, L"StartMinimized", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

bool RegistryManager::GetForceClose() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 0;  // Default to false
    DWORD bufSize = sizeof(DWORD);
    RegQueryValueExW(hKey, L"ForceClose", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return value != 0;
  }
  return false;  // Default to false
}

bool RegistryManager::SetForceClose(bool value) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = value ? 1 : 0;
    RegSetValueExW(hKey, L"ForceClose", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

bool RegistryManager::GetSoundEffect() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 1;  // Default to true
    DWORD bufSize = sizeof(DWORD);
    RegQueryValueExW(hKey, L"SoundEffect", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return value != 0;
  }
  return true;  // Default to true
}

bool RegistryManager::SetSoundEffect(bool value) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = value ? 1 : 0;
    RegSetValueExW(hKey, L"SoundEffect", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

int RegistryManager::GetServiceMode() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 1;
    DWORD bufSize = sizeof(DWORD);
    RegQueryValueExW(hKey, L"ServiceMode", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return static_cast<int>(value);
  }
  return 1;
}

bool RegistryManager::SetServiceMode(int mode) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = static_cast<DWORD>(mode);
    RegSetValueExW(hKey, L"ServiceMode", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

bool RegistryManager::GetProxyService() const {
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 1;
    DWORD bufSize = sizeof(DWORD);
    RegQueryValueExW(hKey, L"ProxyService", nullptr, nullptr, (LPBYTE)&value, &bufSize);
    RegCloseKey(hKey);
    return value != 0;
  }
  return true;
}

bool RegistryManager::SetProxyService(bool value) {
  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferencesRegPath, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    DWORD dwValue = value ? 1 : 0;
    RegSetValueExW(hKey, L"ProxyService", 0, REG_DWORD, (const BYTE*)&dwValue, sizeof(DWORD));
    RegCloseKey(hKey);
    return true;
  }
  return false;
}

