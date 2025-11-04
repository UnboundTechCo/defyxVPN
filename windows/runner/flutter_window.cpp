#include "flutter_window.h"

#include <optional>

#include "dxcore_bridge.h"
#include "proxy_config.h"
#include "system_tray.h"
#include "flutter/generated_plugin_registrant.h"
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>
#include <cstdlib>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

static DXCoreBridge g_dxcore;
static ProxyConfig g_proxy;
static SystemTray* g_system_tray = nullptr;
static std::string vpn_status = "disconnected";
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink;
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink;

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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  auto messenger = flutter_controller_->engine()->messenger();

  if (!g_dxcore.Load()) {
    OutputDebugStringA("[DXcore] Failed to load DXcore.dll\n");
  } else {
    OutputDebugStringA("[DXcore] Successfully loaded DXcore.dll\n");
  }

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
        // Log all progress messages for debugging
        std::string log_msg = "[DXcore Progress] " + msg + "\n";
        OutputDebugStringA(log_msg.c_str());
        
        if (progress_sink) {
          progress_sink->Success(flutter::EncodableValue(msg));
        }
        // Update VPN status based on progress messages
        if (msg.find("Data: VPN connected") != std::string::npos) {
          OutputDebugStringA("[DXcore] VPN connected - updating status and enabling proxy\n");
          vpn_status = "connected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Connected);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Connected");
            g_system_tray->UpdateConnectionStatus(L"\u2714\uFE0F Connected");
          }

          if (g_proxy.EnableProxy("127.0.0.1:5000")) {
            OutputDebugStringA("[Proxy] System proxy enabled on 127.0.0.1:5000\n");
          } else {
            OutputDebugStringA("[Proxy] Failed to enable system proxy\n");
          }
          
          if (status_sink) {
            flutter::EncodableMap m;
            m[flutter::EncodableValue("status")] = flutter::EncodableValue(vpn_status);
            status_sink->Success(flutter::EncodableValue(m));
          }
        } else if (msg.find("Data: VPN failed") != std::string::npos) {
          OutputDebugStringA("[DXcore] VPN failed - updating status to error and disabling proxy\n");
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Error);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Error");
            g_system_tray->UpdateConnectionStatus(L"Error");
          }

          if (g_proxy.DisableProxy()) {
            OutputDebugStringA("[Proxy] System proxy disabled\n");
          } else {
            OutputDebugStringA("[Proxy] Failed to disable system proxy\n");
          }

          if (status_sink) {
            flutter::EncodableMap m;
            m[flutter::EncodableValue("status")] = flutter::EncodableValue(vpn_status);
            status_sink->Success(flutter::EncodableValue(m));
          }
        } else if (msg.find("Data: VPN stopped") != std::string::npos ||
                   msg.find("Data: VPN cancelled") != std::string::npos) {
          OutputDebugStringA("[DXcore] VPN stopped - updating status to disconnected and disabling proxy\n");
          vpn_status = "disconnected";

          if (g_system_tray) {
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Disconnected);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
          }

          if (g_proxy.DisableProxy()) {
            OutputDebugStringA("[Proxy] System proxy disabled\n");
          } else {
            OutputDebugStringA("[Proxy] Failed to disable system proxy\n");
          }
          
          if (status_sink) {
            flutter::EncodableMap m;
            m[flutter::EncodableValue("status")] = flutter::EncodableValue(vpn_status);
            status_sink->Success(flutter::EncodableValue(m));
          }
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
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Disconnected);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
            g_system_tray->UpdateConnectionStatus(L"Disconnected");
          }

          send_status();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "prepare" || method == "grantVpnPermission") {
          result->Success(flutter::EncodableValue(true));
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
          result->Success(flutter::EncodableValue(g_dxcore.MeasurePing()));
          return;
        }
        if (method == "getFlag") {
          result->Success(flutter::EncodableValue(g_dxcore.GetFlag()));
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
            auto fl = g_dxcore.GetFlowLine(is_test);
            result->Success(flutter::EncodableValue(fl));
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }
        if (method == "setConnectionMethod") {
          // No-op on Windows for now
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

            std::string log = "[DXcore] Starting VPN with cache_dir=" + cache_dir + 
                             ", flow=" + flow + ", pattern=" + pattern + "\n";
            OutputDebugStringA(log.c_str());
            
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
            g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Disconnected);
            g_system_tray->UpdateTooltip(L"DefyxVPN - Disconnected");
          }

          send_status();
          result->Success(flutter::EncodableValue(true));
        if (method == "openIntroduction") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "openSpeedTest") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
          return;
        }
        if (method == "openIntroduction") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "openSpeedTest") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "openLogs") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "openPreferences") {
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
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
      // TODO: Implement launch on startup functionality
      break;

    case SystemTray::TrayAction::AutoConnect:
      // TODO: Implement auto-connect functionality
      break;

    case SystemTray::TrayAction::StartMinimized:
      // TODO: Implement start minimized functionality
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
      // Show window first
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


