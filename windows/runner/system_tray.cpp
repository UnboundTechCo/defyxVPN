#include "system_tray.h"
#include "resource.h"
#include <windowsx.h>
#include <uxtheme.h>
#include <dwmapi.h>
#include <gdiplus.h>
#include <shlwapi.h>

#pragma comment(lib, "UxTheme.lib")
#pragma comment(lib, "Dwmapi.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "Shlwapi.lib")

using namespace Gdiplus;

enum PreferredAppMode { Default, AllowDark, ForceDark, ForceLight, Max };
using fnSetPreferredAppMode = PreferredAppMode(WINAPI*)(PreferredAppMode appMode);
using fnFlushMenuThemes = void(WINAPI*)();

SystemTray::SystemTray()
    : window_(nullptr),
      instance_(nullptr),
      callback_(nullptr),
      initialized_(false),
      launch_on_startup_(false),
      auto_connect_(false),
      start_minimized_(false),
      force_close_(false),
      sound_effect_(true),
      proxy_service_(false),
      system_proxy_(true),
      vpn_mode_(false),
      connection_status_(L"Disconnected") {
  ZeroMemory(&nid_, sizeof(NOTIFYICONDATA));
}

SystemTray::~SystemTray() {
  Cleanup();
}

bool SystemTray::Initialize(HWND window, HINSTANCE instance, ActionCallback callback) {
  if (initialized_) {
    return true;
  }

  window_ = window;
  instance_ = instance;
  callback_ = callback;

  nid_.cbSize = sizeof(NOTIFYICONDATA);
  nid_.hWnd = window_;
  nid_.uID = 1;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid_.uCallbackMessage = WM_TRAYICON;
  nid_.hIcon = LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(nid_.szTip, L"DefyxVPN");

  if (!Shell_NotifyIcon(NIM_ADD, &nid_)) {
    return false;
  }

  initialized_ = true;
  return true;
}

void SystemTray::Cleanup() {
  if (initialized_) {
    Shell_NotifyIcon(NIM_DELETE, &nid_);
    initialized_ = false;
  }
}

bool SystemTray::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message != WM_TRAYICON) {
    return false;
  }

  switch (LOWORD(lparam)) {
    case WM_LBUTTONUP:
      ExecuteAction(TrayAction::ToggleWindow);
      return true;
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
      ShowContextMenu(window_);
      return true;
    case WM_LBUTTONDBLCLK:
      ExecuteAction(TrayAction::ToggleWindow);
      return true;
  }

  return false;
}

bool SystemTray::IsSystemDarkMode() {
  HKEY hKey;
  const wchar_t* regPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
  bool isDark = false;

  if (RegOpenKeyExW(HKEY_CURRENT_USER, regPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD value = 0;
    DWORD bufSize = sizeof(DWORD);
    if (RegQueryValueExW(hKey, L"AppsUseLightTheme", nullptr, nullptr, (LPBYTE)&value, &bufSize) == ERROR_SUCCESS) {
      isDark = (value == 0);
    }
    RegCloseKey(hKey);
  }

  return isDark;
}

COLORREF SystemTray::GetMenuBackgroundColor() {
  return IsSystemDarkMode() ? RGB(32, 32, 32) : GetSysColor(COLOR_MENU);
}

COLORREF SystemTray::GetMenuTextColor() {
  return IsSystemDarkMode() ? RGB(255, 255, 255) : GetSysColor(COLOR_MENUTEXT);
}

void SystemTray::ShowContextMenu(HWND window) {
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  bool isDarkMode = IsSystemDarkMode();

  if (isDarkMode) {
    HMODULE hUxtheme = LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (hUxtheme) {
      auto SetPreferredAppMode = reinterpret_cast<fnSetPreferredAppMode>(GetProcAddress(hUxtheme, MAKEINTRESOURCEA(135)));
      auto FlushMenuThemes = reinterpret_cast<fnFlushMenuThemes>(GetProcAddress(hUxtheme, MAKEINTRESOURCEA(136)));

      if (SetPreferredAppMode && FlushMenuThemes) {
        SetPreferredAppMode(AllowDark);
        FlushMenuThemes();
      }

      FreeLibrary(hUxtheme);
    }

    BOOL darkMode = TRUE;
    DwmSetWindowAttribute(window, 20, &darkMode, sizeof(darkMode));
  }

  AppendMenu(menu, MF_STRING, IDM_SHOW_WINDOW, L"DefyxVPN");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);

  std::wstring status_text = connection_status_;
  AppendMenu(menu, MF_STRING, IDM_CONNECTION_STATUS, status_text.c_str());
  AppendMenu(menu, MF_STRING, IDM_PREFERENCES, L"Preferences");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);

  // Section 3: Startup Options
  AppendMenu(menu, MF_STRING | MF_GRAYED, 0, L"Startup Options");
  UINT launch_flags = MF_STRING | (launch_on_startup_ ? MF_CHECKED : MF_UNCHECKED);
  UINT auto_connect_flags = MF_STRING | (auto_connect_ ? MF_CHECKED : MF_UNCHECKED);
  UINT start_min_flags = MF_STRING | (start_minimized_ ? MF_CHECKED : MF_UNCHECKED);
  UINT force_close_flags = MF_STRING | (force_close_ ? MF_CHECKED : MF_UNCHECKED);
  UINT sound_effect_flags = MF_STRING | (sound_effect_ ? MF_CHECKED : MF_UNCHECKED);
  AppendMenu(menu, launch_flags, IDM_LAUNCH_ON_STARTUP, L"    Launch on startup");
  AppendMenu(menu, auto_connect_flags, IDM_AUTO_CONNECT, L"    Auto-connect");
  AppendMenu(menu, sound_effect_flags, IDM_SOUND_EFFECT, L"    Sound Effect");
  AppendMenu(menu, start_min_flags, IDM_START_MINIMIZED, L"    Start minimized");
  AppendMenu(menu, force_close_flags, IDM_FORCE_CLOSE, L"    Force close");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);

  // Section 4: Service Mode
  AppendMenu(menu, MF_STRING | MF_GRAYED, 0, L"Service Mode");
  UINT proxy_flags = MF_STRING | (proxy_service_ ? MF_CHECKED : MF_UNCHECKED);
  UINT system_flags = MF_STRING | (system_proxy_ ? MF_CHECKED : MF_UNCHECKED);
  UINT vpn_flags = MF_STRING | (vpn_mode_ ? MF_CHECKED : MF_UNCHECKED) | MF_GRAYED;
  AppendMenu(menu, proxy_flags, IDM_PROXY_SERVICE, L"    Proxy Service");
  AppendMenu(menu, system_flags, IDM_SYSTEM_PROXY, L"    System Proxy");
  AppendMenu(menu, vpn_flags, IDM_VPN_MODE, L"    VPN (Upcoming)");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);

  // Section 5: Actions
  AppendMenu(menu, MF_STRING, IDM_INTRODUCTION, L"Introduction");
  AppendMenu(menu, MF_STRING, IDM_SPEEDTEST, L"Speedtest");
  AppendMenu(menu, MF_STRING, IDM_LOGS, L"Logs");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);

  // Section 6: Exit
  AppendMenu(menu, MF_STRING, IDM_EXIT, L"Exit");

  POINT cursor;
  GetCursorPos(&cursor);

  SetForegroundWindow(window);

  UINT cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY,
                            cursor.x, cursor.y, 0, window, nullptr);

  DestroyMenu(menu);


  switch (cmd) {
    case IDM_SHOW_WINDOW:
      ExecuteAction(TrayAction::ShowWindow);
      break;
    case IDM_PREFERENCES:
      ExecuteAction(TrayAction::OpenPreferences);
      break;
    case IDM_LAUNCH_ON_STARTUP:
      launch_on_startup_ = !launch_on_startup_;
      ExecuteAction(TrayAction::LaunchOnStartup);
      break;
    case IDM_AUTO_CONNECT:
      auto_connect_ = !auto_connect_;
      ExecuteAction(TrayAction::AutoConnect);
      break;
    case IDM_SOUND_EFFECT:
      sound_effect_ = !sound_effect_;
      ExecuteAction(TrayAction::SoundEffect);
      break;
    case IDM_START_MINIMIZED:
      start_minimized_ = !start_minimized_;
      ExecuteAction(TrayAction::StartMinimized);
      break;
    case IDM_FORCE_CLOSE:
      force_close_ = !force_close_;
      ExecuteAction(TrayAction::ForceClose);
      break;
    case IDM_PROXY_SERVICE:
      if (!proxy_service_) {
        proxy_service_ = true;
        system_proxy_ = false;
        vpn_mode_ = false;
      }
      ExecuteAction(TrayAction::ProxyService);
      break;
    case IDM_SYSTEM_PROXY:
      if (!system_proxy_) {
        proxy_service_ = false;
        system_proxy_ = true;
        vpn_mode_ = false;
      }
      ExecuteAction(TrayAction::SystemProxy);
      break;
    case IDM_VPN_MODE:
      if (!vpn_mode_) {
        proxy_service_ = false;
        system_proxy_ = false;
        vpn_mode_ = true;
      }
      ExecuteAction(TrayAction::VPNMode);
      break;
    case IDM_INTRODUCTION:
      ExecuteAction(TrayAction::OpenIntroduction);
      break;
    case IDM_SPEEDTEST:
      ExecuteAction(TrayAction::OpenSpeedTest);
      break;
    case IDM_LOGS:
      ExecuteAction(TrayAction::OpenLogs);
      break;
    case IDM_CONNECTION_STATUS:
      ExecuteAction(TrayAction::ConnectionStatusClick);
      break;
    case IDM_EXIT:
      ExecuteAction(TrayAction::Exit);
      break;
  }
}

void SystemTray::ExecuteAction(TrayAction action) {
  if (callback_) {
    callback_(action);
  }
}

void SystemTray::UpdateTooltip(const std::wstring& tooltip) {
  if (!initialized_) {
    return;
  }

  wcscpy_s(nid_.szTip, tooltip.c_str());
  Shell_NotifyIcon(NIM_MODIFY, &nid_);
}

HICON SystemTray::CreateIconWithBorder(TrayIconStatus status) {
  static ULONG_PTR gdiplusToken = 0;
  static bool gdiplusInitialized = false;
  if (!gdiplusInitialized) {
    GdiplusStartupInput gdiplusStartupInput;
    Status gdiStatus = GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);
    if (gdiStatus == Ok) {
      gdiplusInitialized = true;
      OutputDebugStringA("[SystemTray] GDI+ initialized successfully\n");
    } else {
      OutputDebugStringA("[SystemTray] Failed to initialize GDI+\n");
      return LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
    }
  }

  const wchar_t* iconFilename = nullptr;
  switch (status) {
    case TrayIconStatus::Connected:
      iconFilename = L"Icon-Connected.png";
      break;
    case TrayIconStatus::Connecting:
      iconFilename = L"Icon-Connecting.png";
      break;
    case TrayIconStatus::Failed:
      iconFilename = L"Icon-Failed.png";
      break;
    case TrayIconStatus::KillSwitch:
      iconFilename = L"Icon-KillSwitch.png";
      break;
    case TrayIconStatus::NoInternet:
      iconFilename = L"Icon-NoInternet.png";
      break;
    case TrayIconStatus::Standby:
    default:
      iconFilename = L"Icon-Standby.png";
      break;
  }

  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  PathRemoveFileSpecW(exePath);

  std::wstring iconPath = exePath;
  iconPath += L"\\data\\flutter_assets\\assets\\icons\\";
  iconPath += iconFilename;

  std::string debugPath = "[SystemTray] Loading icon from: ";
  int len = WideCharToMultiByte(CP_UTF8, 0, iconPath.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (len > 0) {
    std::string path8bit(len, 0);
    WideCharToMultiByte(CP_UTF8, 0, iconPath.c_str(), -1, &path8bit[0], len, nullptr, nullptr);
    debugPath += path8bit + "\n";
    OutputDebugStringA(debugPath.c_str());
  }

  DWORD fileAttrib = GetFileAttributesW(iconPath.c_str());
  if (fileAttrib == INVALID_FILE_ATTRIBUTES) {
    OutputDebugStringA("[SystemTray] Icon file not found, using default icon\n");
    return LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  }

  Bitmap* bitmap = new Bitmap(iconPath.c_str());
  if (!bitmap) {
    OutputDebugStringA("[SystemTray] Failed to create bitmap\n");
    return LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  }

  Status bitmapStatus = bitmap->GetLastStatus();
  if (bitmapStatus != Ok) {
    char errMsg[256];
    sprintf_s(errMsg, "[SystemTray] Bitmap load failed with status: %d\n", bitmapStatus);
    OutputDebugStringA(errMsg);
    delete bitmap;
    return LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  }

  OutputDebugStringA("[SystemTray] Bitmap loaded successfully\n");

  HICON hIcon = nullptr;
  Status iconStatus = bitmap->GetHICON(&hIcon);
  delete bitmap;

  if (iconStatus != Ok || !hIcon) {
    char errMsg[256];
    sprintf_s(errMsg, "[SystemTray] GetHICON failed with status: %d\n", iconStatus);
    OutputDebugStringA(errMsg);
    return LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  }

  OutputDebugStringA("[SystemTray] Icon converted successfully\n");
  return hIcon;
}

void SystemTray::UpdateIcon(TrayIconStatus status) {
  if (!initialized_) {
    return;
  }

  HICON newIcon = CreateIconWithBorder(status);
  if (newIcon) {
    if (nid_.hIcon) {
      DestroyIcon(nid_.hIcon);
    }
    nid_.hIcon = newIcon;
    Shell_NotifyIcon(NIM_MODIFY, &nid_);
  }
}

void SystemTray::UpdateConnectionStatus(const std::wstring& status) {
  connection_status_ = status;
}

void SystemTray::SetLaunchOnStartup(bool value) {
  launch_on_startup_ = value;
}

void SystemTray::SetAutoConnect(bool value) {
  auto_connect_ = value;
}

void SystemTray::SetStartMinimized(bool value) {
  start_minimized_ = value;
}

void SystemTray::SetForceClose(bool value) {
  force_close_ = value;
}

void SystemTray::SetSoundEffect(bool value) {
  sound_effect_ = value;
}

void SystemTray::SetProxyService(bool value) {
  proxy_service_ = value;
}

void SystemTray::SetSystemProxy(bool value) {
  system_proxy_ = value;
}

void SystemTray::SetVPNMode(bool value) {
  vpn_mode_ = value;
}

