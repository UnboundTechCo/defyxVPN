#ifndef RUNNER_SYSTEM_TRAY_H_
#define RUNNER_SYSTEM_TRAY_H_

#include <windows.h>
#include <shellapi.h>
#include <functional>
#include <string>

class SystemTray {
 public:
  enum class TrayIconStatus {
    Standby,
    Connected,
    Connecting,
    Failed,
    KillSwitch,
    NoInternet
  };

  enum class TrayAction {
    ShowWindow,
    ToggleWindow,
    Exit,
    LaunchOnStartup,
    AutoConnect,
    StartMinimized,
    ForceClose,
    SoundEffect,
    ProxyService,
    SystemProxy,
    VPNMode,
    OpenIntroduction,
    OpenSpeedTest,
    OpenLogs,
    OpenPreferences
  };

  using ActionCallback = std::function<void(TrayAction)>;

  SystemTray();
  ~SystemTray();

  bool Initialize(HWND window, HINSTANCE instance, ActionCallback callback);
  void Cleanup();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void UpdateTooltip(const std::wstring& tooltip);
  void UpdateIcon(TrayIconStatus status);
  void UpdateConnectionStatus(const std::wstring& status);
  void SetLaunchOnStartup(bool value);
  void SetAutoConnect(bool value);
  void SetStartMinimized(bool value);
  void SetForceClose(bool value);
  void SetSoundEffect(bool value);
  void SetProxyService(bool value);
  void SetSystemProxy(bool value);
  void SetVPNMode(bool value);
  bool GetStartMinimized() const { return start_minimized_; }
  bool GetForceClose() const { return force_close_; }
  bool GetSoundEffect() const { return sound_effect_; }
  bool GetProxyService() const { return proxy_service_; }
  bool GetSystemProxy() const { return system_proxy_; }
  bool GetVPNMode() const { return vpn_mode_; }

  static constexpr UINT WM_TRAYICON = WM_USER + 1;

 private:
  void ShowContextMenu(HWND window);
  void ExecuteAction(TrayAction action);
  HICON CreateIconWithBorder(TrayIconStatus status);
  bool IsSystemDarkMode();
  COLORREF GetMenuBackgroundColor();
  COLORREF GetMenuTextColor();

  HWND window_;
  HINSTANCE instance_;
  NOTIFYICONDATA nid_;
  ActionCallback callback_;
  bool initialized_;

  // Menu item IDs
  static constexpr UINT IDM_SHOW_WINDOW = 1001;
  static constexpr UINT IDM_EXIT = 1002;
  static constexpr UINT IDM_PREFERENCES = 1003;

  // Startup Options
  static constexpr UINT IDM_LAUNCH_ON_STARTUP = 1010;
  static constexpr UINT IDM_AUTO_CONNECT = 1011;
  static constexpr UINT IDM_START_MINIMIZED = 1012;
  static constexpr UINT IDM_FORCE_CLOSE = 1013;
  static constexpr UINT IDM_SOUND_EFFECT = 1014;

  // Service Mode
  static constexpr UINT IDM_PROXY_SERVICE = 1020;
  static constexpr UINT IDM_SYSTEM_PROXY = 1021;
  static constexpr UINT IDM_VPN_MODE = 1022;

  // Other actions
  static constexpr UINT IDM_INTRODUCTION = 1030;
  static constexpr UINT IDM_SPEEDTEST = 1031;
  static constexpr UINT IDM_LOGS = 1032;

  // Checkbox states
  bool launch_on_startup_;
  bool auto_connect_;
  bool start_minimized_;
  bool force_close_;
  bool sound_effect_;
  bool proxy_service_;
  bool system_proxy_;
  bool vpn_mode_;
  std::wstring connection_status_;
};

#endif

