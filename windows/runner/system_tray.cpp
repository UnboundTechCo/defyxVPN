#include "system_tray.h"
#include "resource.h"
#include <windowsx.h>

SystemTray::SystemTray()
    : window_(nullptr),
      instance_(nullptr),
      callback_(nullptr),
      initialized_(false) {
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

void SystemTray::ShowContextMenu(HWND window) {
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  AppendMenu(menu, MF_STRING, IDM_SHOW_WINDOW, L"Show DefyxVPN");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, IDM_RESTART_PROXY, L"Restart Proxy");
  AppendMenu(menu, MF_STRING, IDM_RESTART_PROGRAM, L"Restart Program");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
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
    case IDM_RESTART_PROXY:
      ExecuteAction(TrayAction::RestartProxy);
      break;
    case IDM_RESTART_PROGRAM:
      ExecuteAction(TrayAction::RestartProgram);
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

