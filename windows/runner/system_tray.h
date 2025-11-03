#ifndef RUNNER_SYSTEM_TRAY_H_
#define RUNNER_SYSTEM_TRAY_H_

#include <windows.h>
#include <shellapi.h>
#include <functional>
#include <string>

class SystemTray {
 public:
  enum class TrayAction {
    ShowWindow,
    ToggleWindow,
    RestartProxy,
    RestartProgram,
    Exit
  };

  using ActionCallback = std::function<void(TrayAction)>;

  SystemTray();
  ~SystemTray();

  bool Initialize(HWND window, HINSTANCE instance, ActionCallback callback);
  void Cleanup();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void UpdateTooltip(const std::wstring& tooltip);

  static constexpr UINT WM_TRAYICON = WM_USER + 1;

 private:
  void ShowContextMenu(HWND window);
  void ExecuteAction(TrayAction action);

  HWND window_;
  HINSTANCE instance_;
  NOTIFYICONDATA nid_;
  ActionCallback callback_;
  bool initialized_;

  static constexpr UINT IDM_SHOW_WINDOW = 1001;
  static constexpr UINT IDM_RESTART_PROXY = 1002;
  static constexpr UINT IDM_RESTART_PROGRAM = 1003;
  static constexpr UINT IDM_EXIT = 1004;
};

#endif

