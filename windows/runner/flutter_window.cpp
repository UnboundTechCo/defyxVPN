#include "flutter_window.h"

#include <optional>
#include <thread>
#include <memory>

#include "dxcore_bridge.h"
#include "proxy_config.h"
#include "system_tray.h"
#include "flutter/generated_plugin_registrant.h"
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>
#include <shellapi.h>
#pragma comment(lib, "shell32.lib")

#define WM_PING_RESULT (WM_USER + 2)
// Marshal background callbacks to the platform thread
#define WM_PROGRESS_RESULT (WM_USER + 3)
#define WM_STATUS_RESULT (WM_USER + 4)
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink;
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink;
static std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_ping_result;
static HWND g_window_handle = nullptr;

static bool IsRunningAsAdministrator() {
  BOOL isAdmin = FALSE;
  PSID administratorsGroup = NULL;
  SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;

  if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                &administratorsGroup)) {
    if (!CheckTokenMembership(NULL, administratorsGroup, &isAdmin)) {
      isAdmin = FALSE;
    }
    FreeSid(administratorsGroup);
  }

  return isAdmin == TRUE;
}

static bool RequestAdministratorPrivileges() {
  wchar_t szPath[MAX_PATH];
  if (GetModuleFileNameW(NULL, szPath, ARRAYSIZE(szPath)) == 0) {
    return false;
  }

  LPWSTR* szArglist;
  int nArgs;
  szArglist = CommandLineToArgvW(GetCommandLineW(), &nArgs);
  
  std::wstring args;
  for (int i = 1; i < nArgs; i++) {
    if (i > 1) args += L" ";
    args += szArglist[i];
  }
  LocalFree(szArglist);

  SHELLEXECUTEINFOW sei = { sizeof(sei) };
  sei.lpVerb = L"runas";
  sei.lpFile = szPath;
  sei.lpParameters = args.c_str();
  sei.hwnd = g_window_handle;
  sei.nShow = SW_NORMAL;

  if (!ShellExecuteExW(&sei)) {
    DWORD dwError = GetLastError();
    if (dwError == ERROR_CANCELLED) {
      return false;
    }
  }

  return true;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

static DXCoreBridge g_dxcore;
static ProxyConfig g_proxy;
static SystemTray* g_system_tray = nullptr;
static std::string vpn_status = "disconnected";

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  bool shouldShowWindow = true;

  HKEY hKeyMinimized;
  const wchar_t* regPathMinimized = L"Software\\DefyxVPN";
  const wchar_t* valueName = L"StartMinimized";

  if (RegOpenKeyExW(HKEY_CURRENT_USER, regPathMinimized, 0, KEY_QUERY_VALUE, &hKeyMinimized) == ERROR_SUCCESS) {
    DWORD value = 0;
    DWORD dataSize = sizeof(DWORD);
    if (RegQueryValueExW(hKeyMinimized, valueName, nullptr, nullptr, (BYTE*)&value, &dataSize) == ERROR_SUCCESS) {
      if (value == 1) {
        shouldShowWindow = false;
      }
    }
    RegCloseKey(hKeyMinimized);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&, shouldShowWindow]() {
    if (shouldShowWindow) {
      this->Show();
    }
  });

  flutter_controller_->ForceRedraw();

  auto messenger = flutter_controller_->engine()->messenger();
  // Cache window handle for posting messages from background threads
  g_window_handle = GetHandle();

  g_dxcore.Load();

  class StatusHandler : public flutter::StreamHandler<flutter::EncodableValue> {
   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(const flutter::EncodableValue* arguments,
                     std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
      status_sink = std::move(events);
      return nullptr;
    }
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override {
      status_sink.reset();
      return nullptr;
    }
  };
  auto status_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "com.defyx.vpn_events",
      &flutter::StandardMethodCodec::GetInstance());
  status_channel->SetStreamHandler(std::make_unique<StatusHandler>());

  class ProgressHandler : public flutter::StreamHandler<flutter::EncodableValue> {
   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(const flutter::EncodableValue* arguments,
                     std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
      progress_sink = std::move(events);
      g_dxcore.SetProgressCallback([](const std::string& msg) {
        // Always marshal to platform thread
        PostMessage(g_window_handle, WM_PROGRESS_RESULT, 0,
                    reinterpret_cast<LPARAM>(new std::string(msg)));

        if (msg.find("Data: VPN connected") != std::string::npos) {
          vpn_status = "connected";

          // Emit status on platform thread
          PostMessage(g_window_handle, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(vpn_status)));

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Connected);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Connected");
            g_system_tray->UpdateConnectionStatus(L"\u2714\uFE0F Connected");
          }

          std::thread([]() {
            g_proxy.EnableProxy("127.0.0.1:5000");
          }).detach();
        } else if (msg.find("Data: VPN failed") != std::string::npos) {
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Failed);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Error");
            g_system_tray->UpdateConnectionStatus(L"Error");
          }

          std::thread([]() {
            g_proxy.DisableProxy();
          }).detach();

          // Emit status on platform thread
          PostMessage(g_window_handle, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(vpn_status)));
        } else if (msg.find("Data: VPN stopped") != std::string::npos ||
                   msg.find("Data: VPN cancelled") != std::string::npos) {
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
          }

          std::thread([]() {
            g_proxy.DisableProxy();
          }).detach();

          // Emit status on platform thread
          PostMessage(g_window_handle, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(vpn_status)));
        }
      });
      return nullptr;
    }
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override {
      progress_sink.reset();
      return nullptr;
    }
  };
  auto progress_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "com.defyx.progress_events",
      &flutter::StandardMethodCodec::GetInstance());
  progress_channel->SetStreamHandler(std::make_unique<ProgressHandler>());

  // Method channel
  auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.defyx.vpn",
      &flutter::StandardMethodCodec::GetInstance());

  auto send_status = [&]() {
    if (status_sink) {
      flutter::EncodableMap m;
      m[flutter::EncodableValue("status")] = flutter::EncodableValue(vpn_status);
      status_sink->Success(flutter::EncodableValue(m));
    }
  };

  method_channel->SetMethodCallHandler(
      [&, messenger](const flutter::MethodCall<flutter::EncodableValue>& call,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();

        auto get_string_arg = [&](const flutter::EncodableMap& map,
                                  const char* key) -> std::string {
          auto it = map.find(flutter::EncodableValue(key));
          if (it != map.end() && std::holds_alternative<std::string>(it->second)) {
            return std::get<std::string>(it->second);
          }
          return {};
        };

        if (method == "connect") {
          vpn_status = "connected";  // Stub: assume connected when controlled externally
          send_status();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "disconnect") {
          g_dxcore.StopVPN();
          g_dxcore.Stop();
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
          }

          send_status();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "prepareVPN" || method == "grantVpnPermission") {
          bool needsAdmin = false;
          if (g_system_tray) {
            needsAdmin = g_system_tray->GetVPNMode();
          }

          if (!needsAdmin) {
            result->Success(flutter::EncodableValue(true));
          } else {
            if (IsRunningAsAdministrator()) {
              result->Success(flutter::EncodableValue(true));
            } else {
              bool elevationRequested = RequestAdministratorPrivileges();
              if (elevationRequested) {
                result->Success(flutter::EncodableValue(true));
                PostQuitMessage(0);
              } else {
                result->Success(flutter::EncodableValue(false));
              }
            }
          }
          return;
        }
        if (method == "startTun2socks" || method == "stopTun2Socks") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "getVpnStatus") {
          result->Success(flutter::EncodableValue(vpn_status));
          return;
        }
        if (method == "isTunnelRunning") {
          result->Success(flutter::EncodableValue(vpn_status == "connected"));
          return;
        }
        if (method == "calculatePing") {
          // Store the result callback to use when ping completes
          pending_ping_result = std::move(result);
          
          // Each click triggers a fresh ping in background thread
          std::thread([&]() {
            try {
              // Lower thread priority to prevent UI blocking
              SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);
              
              int ping = g_dxcore.MeasurePing();
              
              // Handle edge cases
              if (ping < 0) ping = 0;
              if (ping > 9999) ping = 9999;
              if (ping == 0) ping = 100; // Default for invalid ping
              

              
              // Post the fresh result back to main thread for UI update
              PostMessage(g_window_handle, WM_PING_RESULT, 0, 
                         static_cast<LPARAM>(ping));
              
            } catch (...) {
              // Post default value on error
              PostMessage(g_window_handle, WM_PING_RESULT, 0, 
                         static_cast<LPARAM>(100));
            }
          }).detach();
          
          return; // Don't call result->Success() here, we'll call it when ping completes
        }
        if (method == "getFlag") {
          std::thread([result = std::move(result)]() {
            std::string flag = "xx"; // default disconnected state
            
            // Only get VPN server location if VPN is connected
            if (vpn_status == "connected") {
              flag = g_dxcore.GetFlag();
              // If still failed to get flag through VPN, keep "xx" for disconnected state
              if (flag.empty()) {
                flag = "xx";
              }
            }
            
            result->Success(flutter::EncodableValue(flag));
          }).detach();
          return;
        }
        if (method == "setAsnName") {
          g_dxcore.SetAsnName();
          result->Success();
          return;
        }
        if (method == "setTimezone") {
          if (call.arguments() && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
            auto m = std::get<flutter::EncodableMap>(*call.arguments());
            auto tz_str = get_string_arg(m, "timezone");
            try {
              float tz = std::stof(tz_str);
              g_dxcore.SetTimeZone(tz);
              result->Success(flutter::EncodableValue(true));
            } catch (...) {
              result->Error("INVALID_ARGUMENT", "timezone is invalid");
            }
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }
        if (method == "getFlowLine") {
          if (call.arguments() && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
            auto m = std::get<flutter::EncodableMap>(*call.arguments());
            auto is_test_str = get_string_arg(m, "isTest");
            bool is_test = (is_test_str == "true" || is_test_str == "1");
            std::thread([is_test, result = std::move(result)]() mutable {
              try {
                std::string fl = g_dxcore.GetFlowLine(is_test);
                result->Success(flutter::EncodableValue(fl));
              } catch (...) {
                result->Success(flutter::EncodableValue(std::string()));
              }
            }).detach();
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }
        if (method == "setConnectionMethod") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "startVPN") {
          if (call.arguments() && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
            auto m = std::get<flutter::EncodableMap>(*call.arguments());
            auto flow = get_string_arg(m, "flowLine");
            auto pattern = get_string_arg(m, "pattern");

            // Build cache dir under %LOCALAPPDATA%\DefyxVPN\cache (without SHGetKnownFolderPath)
            wchar_t env_buf[32767];
            DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", env_buf, 32767);
            std::wstring cache_dir_w;
            if (n > 0 && n < 32767) {
              cache_dir_w = std::wstring(env_buf) + L"\\DefyxVPN\\cache";
              CreateDirectoryW((std::wstring(cache_dir_w.substr(0, cache_dir_w.find_last_of(L"\\")))).c_str(), NULL);
              CreateDirectoryW(cache_dir_w.c_str(), NULL);
            } else {
              cache_dir_w = L"C:\\Windows\\Temp\\DefyxVPN\\cache";
              CreateDirectoryW(L"C:\\Windows\\Temp\\DefyxVPN", NULL);
              CreateDirectoryW(L"C:\\Windows\\Temp\\DefyxVPN\\cache", NULL);
            }

            auto WideToUtf8 = [](const std::wstring& w) -> std::string {
              if (w.empty()) return std::string();
              int size = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
              if (size <= 0) return std::string();
              std::string out;
              out.resize(size - 1);
              WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, out.data(), size - 1, nullptr, nullptr);
              return out;
            };
            auto cache_dir = WideToUtf8(cache_dir_w);


            
            g_dxcore.StartVPN(cache_dir, flow, pattern);

            vpn_status = "connecting";
            if (g_system_tray) {
              g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Connecting);
              g_system_tray->UpdateTooltip(L"DefyxVPN - Connecting...");
              g_system_tray->UpdateConnectionStatus(L"Connecting...");
            }

            result->Success(flutter::EncodableValue(true));
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }
        if (method == "stopVPN") {
          g_dxcore.StopVPN();
          g_proxy.DisableProxy();
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
          }

          send_status();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "isVPNPrepared") {
          // On Windows, VPN is always "prepared" since we don't need special preparation
          result->Success(flutter::EncodableValue(true));
          return;
        }

        result->NotImplemented();
      });

  system_tray_ = std::make_unique<SystemTray>();
  system_tray_->Initialize(
      GetHandle(),
      GetModuleHandle(nullptr),
      [this](SystemTray::TrayAction action) {
        HandleTrayAction(action);
      });

  g_system_tray = system_tray_.get();

  if (system_tray_) {
    system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
    system_tray_->UpdateTooltip(L"DefyxVPN - Ready");
  }

  HKEY hKey;
  const wchar_t* appName = L"DefyxVPN";
  const wchar_t* regPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

  if (RegOpenKeyExW(HKEY_CURRENT_USER, regPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    wchar_t existingPath[MAX_PATH] = {0};
    DWORD bufSize = sizeof(existingPath);
    if (RegQueryValueExW(hKey, appName, nullptr, nullptr, (LPBYTE)existingPath, &bufSize) == ERROR_SUCCESS) {
      if (system_tray_) {
        system_tray_->SetLaunchOnStartup(true);
      }
    }
    RegCloseKey(hKey);
  }

  const wchar_t* prefRegPath = L"Software\\DefyxVPN";
  if (RegOpenKeyExW(HKEY_CURRENT_USER, prefRegPath, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
    DWORD autoConnect = 0;
    DWORD bufSize = sizeof(DWORD);
    if (RegQueryValueExW(hKey, L"AutoConnect", nullptr, nullptr, (LPBYTE)&autoConnect, &bufSize) == ERROR_SUCCESS) {
      if (system_tray_) {
        system_tray_->SetAutoConnect(autoConnect != 0);
      }
    }

    DWORD startMinimized = 0;
    bufSize = sizeof(DWORD);
    if (RegQueryValueExW(hKey, L"StartMinimized", nullptr, nullptr, (LPBYTE)&startMinimized, &bufSize) == ERROR_SUCCESS) {
      if (system_tray_) {
        system_tray_->SetStartMinimized(startMinimized != 0);
      }
    }

    DWORD forceClose = 1;
    bufSize = sizeof(DWORD);
    if (RegQueryValueExW(hKey, L"ForceClose", nullptr, nullptr, (LPBYTE)&forceClose, &bufSize) == ERROR_SUCCESS) {
      if (system_tray_) {
        system_tray_->SetForceClose(forceClose != 0);
      }
    }

    DWORD soundEffect = 1;
    bufSize = sizeof(DWORD);
    if (RegQueryValueExW(hKey, L"SoundEffect", nullptr, nullptr, (LPBYTE)&soundEffect, &bufSize) == ERROR_SUCCESS) {
      if (system_tray_) {
        system_tray_->SetSoundEffect(soundEffect != 0);
      }

      if (flutter_controller_) {
        auto sound_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());

        flutter::EncodableMap args;
        args[flutter::EncodableValue("value")] = flutter::EncodableValue(soundEffect != 0);
        sound_channel->InvokeMethod("setSoundEffect", std::make_unique<flutter::EncodableValue>(args));
      }
    }

    RegCloseKey(hKey);
  }

  if (system_tray_ && system_tray_->GetAutoConnect()) {
    std::thread([this]() {
      std::this_thread::sleep_for(std::chrono::milliseconds(1000));

      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());

        channel->InvokeMethod("triggerAutoConnect", nullptr);
      }
    }).detach();
  }

  return true;
}

void FlutterWindow::OnDestroy() {
  g_system_tray = nullptr;

  if (system_tray_) {
    system_tray_->Cleanup();
    system_tray_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (system_tray_ && system_tray_->HandleMessage(message, wparam, lparam)) {
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (system_tray_ && !system_tray_->GetForceClose()) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      } else {
        DestroyWindow(hwnd);
        return 0;
      }
      break;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_PING_RESULT: {
      int ping_value = static_cast<int>(lparam);
      if (pending_ping_result) {
        pending_ping_result->Success(flutter::EncodableValue(ping_value));
        pending_ping_result.reset(); // Clear the callback after use
      }
      return 0;
    }
    case WM_PROGRESS_RESULT: {
      std::unique_ptr<std::string> msg_ptr(reinterpret_cast<std::string*>(lparam));
      if (progress_sink) {
        const std::string msg = msg_ptr ? *msg_ptr : std::string();
        progress_sink->Success(flutter::EncodableValue(msg));
      }
      return 0;
    }
    case WM_STATUS_RESULT: {
      std::unique_ptr<std::string> status_ptr(reinterpret_cast<std::string*>(lparam));
      if (status_sink) {
        const std::string status = status_ptr ? *status_ptr : std::string();
        flutter::EncodableMap m;
        m[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
        status_sink->Success(flutter::EncodableValue(m));
      }
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleTrayAction(SystemTray::TrayAction action) {
  HWND hwnd = GetHandle();

  switch (action) {
    case SystemTray::TrayAction::ShowWindow:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      break;

    case SystemTray::TrayAction::ToggleWindow:
      if (IsWindowVisible(hwnd)) {
        ShowWindow(hwnd, SW_HIDE);
      } else {
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
      }
      break;

    case SystemTray::TrayAction::LaunchOnStartup:
      {
        HKEY hKey;
        const wchar_t* appName = L"DefyxVPN";
        const wchar_t* regPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

        if (RegOpenKeyExW(HKEY_CURRENT_USER, regPath, 0, KEY_SET_VALUE | KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
          wchar_t exePath[MAX_PATH];
          GetModuleFileNameW(nullptr, exePath, MAX_PATH);

          wchar_t existingPath[MAX_PATH] = {0};
          DWORD bufSize = sizeof(existingPath);
          LONG queryResult = RegQueryValueExW(hKey, appName, nullptr, nullptr, (LPBYTE)existingPath, &bufSize);

          if (queryResult == ERROR_SUCCESS) {
            RegDeleteValueW(hKey, appName);
            if (system_tray_) {
              system_tray_->SetLaunchOnStartup(false);
            }
          } else {
            std::wstring startupCommand = std::wstring(exePath) + L" --startup";
            RegSetValueExW(hKey, appName, 0, REG_SZ, (const BYTE*)startupCommand.c_str(), static_cast<DWORD>((startupCommand.length() + 1) * sizeof(wchar_t)));
            if (system_tray_) {
              system_tray_->SetLaunchOnStartup(true);
            }
          }
          RegCloseKey(hKey);
        }
      }
      break;

    case SystemTray::TrayAction::AutoConnect:
      {
        HKEY hKey;
        const wchar_t* regPath = L"Software\\DefyxVPN";
        const wchar_t* valueName = L"AutoConnect";

        if (RegCreateKeyExW(HKEY_CURRENT_USER, regPath, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
          bool currentValue = system_tray_->GetAutoConnect();
          DWORD value = currentValue ? 1 : 0;
          RegSetValueExW(hKey, valueName, 0, REG_DWORD, (const BYTE*)&value, sizeof(DWORD));
          RegCloseKey(hKey);

          if (flutter_controller_) {
            auto messenger = flutter_controller_->engine()->messenger();
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "com.defyx.vpn",
                &flutter::StandardMethodCodec::GetInstance());

            flutter::EncodableMap args;
            args[flutter::EncodableValue("value")] = flutter::EncodableValue(currentValue);
            channel->InvokeMethod("setAutoConnect", std::make_unique<flutter::EncodableValue>(args));
          }
        }
      }
      break;

    case SystemTray::TrayAction::StartMinimized:
      {
        HKEY hKey;
        const wchar_t* regPath = L"Software\\DefyxVPN";
        const wchar_t* valueName = L"StartMinimized";

        if (RegCreateKeyExW(HKEY_CURRENT_USER, regPath, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
          bool currentValue = system_tray_->GetStartMinimized();
          DWORD value = currentValue ? 1 : 0;
          RegSetValueExW(hKey, valueName, 0, REG_DWORD, (const BYTE*)&value, sizeof(DWORD));
          RegCloseKey(hKey);

          if (flutter_controller_) {
            auto messenger = flutter_controller_->engine()->messenger();
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "com.defyx.vpn",
                &flutter::StandardMethodCodec::GetInstance());

            flutter::EncodableMap args;
            args[flutter::EncodableValue("value")] = flutter::EncodableValue(currentValue);
            channel->InvokeMethod("setStartMinimized", std::make_unique<flutter::EncodableValue>(args));
          }
        }
      }
      break;

    case SystemTray::TrayAction::ForceClose:
      {
        HKEY hKey;
        const wchar_t* regPath = L"Software\\DefyxVPN";
        const wchar_t* valueName = L"ForceClose";

        if (RegCreateKeyExW(HKEY_CURRENT_USER, regPath, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
          bool currentValue = system_tray_->GetForceClose();
          DWORD value = currentValue ? 1 : 0;
          RegSetValueExW(hKey, valueName, 0, REG_DWORD, (const BYTE*)&value, sizeof(DWORD));
          RegCloseKey(hKey);

          if (flutter_controller_) {
            auto messenger = flutter_controller_->engine()->messenger();
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "com.defyx.vpn",
                &flutter::StandardMethodCodec::GetInstance());

            flutter::EncodableMap args;
            args[flutter::EncodableValue("value")] = flutter::EncodableValue(currentValue);
            channel->InvokeMethod("setForceClose", std::make_unique<flutter::EncodableValue>(args));
          }
        }
      }
      break;

    case SystemTray::TrayAction::SoundEffect:
      {
        HKEY hKey;
        const wchar_t* regPath = L"Software\\DefyxVPN";
        const wchar_t* valueName = L"SoundEffect";

        if (RegCreateKeyExW(HKEY_CURRENT_USER, regPath, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
          bool currentValue = system_tray_->GetSoundEffect();
          DWORD value = currentValue ? 1 : 0;
          RegSetValueExW(hKey, valueName, 0, REG_DWORD, (const BYTE*)&value, sizeof(DWORD));
          RegCloseKey(hKey);

          if (flutter_controller_) {
            auto messenger = flutter_controller_->engine()->messenger();
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, "com.defyx.vpn",
                &flutter::StandardMethodCodec::GetInstance());

            flutter::EncodableMap args;
            args[flutter::EncodableValue("value")] = flutter::EncodableValue(currentValue);
            channel->InvokeMethod("setSoundEffect", std::make_unique<flutter::EncodableValue>(args));
          }
        }
      }
      break;

    case SystemTray::TrayAction::ProxyService:
      // TODO: Implement proxy service mode
      break;

    case SystemTray::TrayAction::SystemProxy:
      // TODO: Implement system proxy mode
      break;

    case SystemTray::TrayAction::VPNMode:
      // TODO: Implement VPN mode (currently disabled)
      break;

    case SystemTray::TrayAction::OpenIntroduction:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());
        channel->InvokeMethod("openIntroduction", nullptr);
      }
      break;

    case SystemTray::TrayAction::OpenSpeedTest:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());
        channel->InvokeMethod("openSpeedTest", nullptr);
      }
      break;

    case SystemTray::TrayAction::OpenLogs:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());
        channel->InvokeMethod("openLogs", nullptr);
      }
      break;

    case SystemTray::TrayAction::OpenPreferences:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());
        channel->InvokeMethod("openPreferences", nullptr);
      }
      break;

    case SystemTray::TrayAction::Exit:
      DestroyWindow(hwnd);
      break;
  }
}


