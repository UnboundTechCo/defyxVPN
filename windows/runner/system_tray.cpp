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

HICON SystemTray::CreateIconWithBorder(TrayIconStatus status) {
  HICON baseIcon = LoadIcon(instance_, MAKEINTRESOURCE(IDI_APP_ICON));
  if (!baseIcon) return nullptr;

  int canvasSize = 45;
  int iconSize = 41;
  int borderWidth = 4;
  int offsetX = (canvasSize - iconSize) / 2;
  int offsetY = (canvasSize - iconSize) / 2;

  HDC hdcScreen = GetDC(nullptr);
  HDC hdcMem = CreateCompatibleDC(hdcScreen);

  BITMAPINFO bmi = {0};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = canvasSize;
  bmi.bmiHeader.biHeight = -canvasSize;
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  BYTE* pBits = nullptr;
  HBITMAP hbmColor = CreateDIBSection(hdcScreen, &bmi, DIB_RGB_COLORS, (void**)&pBits, nullptr, 0);
  HBITMAP hbmOldColor = (HBITMAP)SelectObject(hdcMem, hbmColor);

  memset(pBits, 0, canvasSize * canvasSize * 4);

  DrawIconEx(hdcMem, offsetX, offsetY, baseIcon, iconSize, iconSize, 0, nullptr, DI_NORMAL);

  if (status != TrayIconStatus::Disconnected && pBits) {
    COLORREF borderColor;
    switch (status) {
      case TrayIconStatus::Connected:
        borderColor = RGB(0, 255, 0);
        break;
      case TrayIconStatus::Connecting:
        borderColor = RGB(30, 144, 255);
        break;
      case TrayIconStatus::Error:
        borderColor = RGB(255, 0, 0);
        break;
      default:
        borderColor = RGB(128, 128, 128);
        break;
    }

    BYTE r = GetRValue(borderColor);
    BYTE g = GetGValue(borderColor);
    BYTE b = GetBValue(borderColor);

    int centerX = canvasSize / 2;
    int centerY = canvasSize / 2;
    int outerRadius = iconSize / 2 + borderWidth / 2;
    int innerRadius = iconSize / 2 - borderWidth / 2;

    for (int y = 0; y < canvasSize; y++) {
      for (int x = 0; x < canvasSize; x++) {
        int dx = x - centerX;
        int dy = y - centerY;
        int distSq = dx * dx + dy * dy;
        int outerRadiusSq = outerRadius * outerRadius;
        int innerRadiusSq = innerRadius * innerRadius;

        if (distSq <= outerRadiusSq && distSq >= innerRadiusSq) {
          int index = (y * canvasSize + x) * 4;
          pBits[index + 0] = b;
          pBits[index + 1] = g;
          pBits[index + 2] = r;
          pBits[index + 3] = 255;
        }
      }
    }
  }

  HBITMAP hbmMask = CreateBitmap(canvasSize, canvasSize, 1, 1, nullptr);
  HDC hdcMask = CreateCompatibleDC(hdcScreen);
  HBITMAP hbmOldMask = (HBITMAP)SelectObject(hdcMask, hbmMask);

  RECT fullRect = {0, 0, canvasSize, canvasSize};
  FillRect(hdcMask, &fullRect, (HBRUSH)GetStockObject(BLACK_BRUSH));

  SelectObject(hdcMem, hbmOldColor);
  SelectObject(hdcMask, hbmOldMask);

  ICONINFO iconInfo = {0};
  iconInfo.fIcon = TRUE;
  iconInfo.hbmColor = hbmColor;
  iconInfo.hbmMask = hbmMask;

  HICON newIcon = CreateIconIndirect(&iconInfo);

  DeleteObject(hbmColor);
  DeleteObject(hbmMask);
  DeleteDC(hdcMem);
  DeleteDC(hdcMask);
  ReleaseDC(nullptr, hdcScreen);
  DestroyIcon(baseIcon);

  return newIcon;
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
