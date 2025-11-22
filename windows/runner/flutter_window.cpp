#include "flutter_window.h"

#include <optional>
#include <thread>
#include <memory>

#include "dxcore_bridge.h"
#include "system_tray.h"
#include "registry_manager.h"
#include "vpn_channel_handler.h"
#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

static DXCoreBridge g_dxcore;
static SystemTray* g_system_tray = nullptr;

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

  // Check if window should start minimized
  RegistryManager registry;
  bool shouldShowWindow = !registry.GetStartMinimized();

  flutter_controller_->engine()->SetNextFrameCallback([&, shouldShowWindow]() {
    if (shouldShowWindow) {
      this->Show();
    }
  });

  flutter_controller_->ForceRedraw();

  auto messenger = flutter_controller_->engine()->messenger();

  g_dxcore.Load();

  // Setup VPN channel handler for all Flutter communication
  vpn_channel_handler_ = std::make_unique<VPNChannelHandler>(
      messenger, GetHandle(), &g_dxcore, nullptr);
  vpn_channel_handler_->SetupChannels();

  // Initialize system tray
  system_tray_ = std::make_unique<SystemTray>();
  system_tray_->Initialize(
      GetHandle(),
      GetModuleHandle(nullptr),
      [this](SystemTray::TrayAction action) {
        HandleTrayAction(action);
      });

  g_system_tray = system_tray_.get();

  // Update VPN channel handler with system tray reference
  if (vpn_channel_handler_) {
    vpn_channel_handler_ = std::make_unique<VPNChannelHandler>(
        messenger, GetHandle(), &g_dxcore, g_system_tray);
    vpn_channel_handler_->SetupChannels();
  }

  if (system_tray_) {
    system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
    system_tray_->UpdateTooltip(L"DefyxVPN - Ready");
  }

  // Load preferences from registry using RegistryManager
  if (system_tray_) {
    system_tray_->SetLaunchOnStartup(registry.IsLaunchOnStartupEnabled());
    system_tray_->SetAutoConnect(registry.GetAutoConnect());
    system_tray_->SetStartMinimized(registry.GetStartMinimized());
    system_tray_->SetForceClose(registry.GetForceClose());

    bool soundEffect = registry.GetSoundEffect();
    system_tray_->SetSoundEffect(soundEffect);

    bool proxyService = registry.GetProxyService();
    int serviceMode = registry.GetServiceMode();
    if (serviceMode == 0) {
      system_tray_->SetProxyService(proxyService);
      system_tray_->SetSystemProxy(false);
      system_tray_->SetVPNMode(false);
    } else if (serviceMode == 1) {
      system_tray_->SetProxyService(false);
      system_tray_->SetSystemProxy(true);
      system_tray_->SetVPNMode(false);
    } else if (serviceMode == 2) {
      system_tray_->SetProxyService(false);
      system_tray_->SetSystemProxy(false);
      system_tray_->SetVPNMode(true);
    }

    if (flutter_controller_) {
      auto sound_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.defyx.vpn",
          &flutter::StandardMethodCodec::GetInstance());

      flutter::EncodableMap args;
      args[flutter::EncodableValue("value")] = flutter::EncodableValue(soundEffect);
      sound_channel->InvokeMethod("setSoundEffect", std::make_unique<flutter::EncodableValue>(args));
    }
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
      if (vpn_channel_handler_) {
        vpn_channel_handler_->HandlePingResult(ping_value);
      }
      return 0;
    }
    case WM_PROGRESS_RESULT: {
      std::unique_ptr<std::string> msg_ptr(reinterpret_cast<std::string*>(lparam));
      if (vpn_channel_handler_) {
        const std::string msg = msg_ptr ? *msg_ptr : std::string();
        vpn_channel_handler_->HandleProgressResult(msg);
      }
      return 0;
    }
    case WM_STATUS_RESULT: {
      std::unique_ptr<std::string> status_ptr(reinterpret_cast<std::string*>(lparam));
      if (vpn_channel_handler_) {
        const std::string status = status_ptr ? *status_ptr : std::string();
        vpn_channel_handler_->HandleStatusResult(status);
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
        RegistryManager registry;
        bool isEnabled = registry.IsLaunchOnStartupEnabled();
        registry.SetLaunchOnStartup(!isEnabled);
        if (system_tray_) {
          system_tray_->SetLaunchOnStartup(!isEnabled);
        }
      }
      break;

    case SystemTray::TrayAction::AutoConnect:
      {
        RegistryManager registry;
        bool currentValue = system_tray_->GetAutoConnect();
        registry.SetAutoConnect(currentValue);

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
      break;

    case SystemTray::TrayAction::StartMinimized:
      {
        RegistryManager registry;
        bool currentValue = system_tray_->GetStartMinimized();
        registry.SetStartMinimized(currentValue);

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
      break;

    case SystemTray::TrayAction::ForceClose:
      {
        RegistryManager registry;
        bool currentValue = system_tray_->GetForceClose();
        registry.SetForceClose(currentValue);

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
      break;

    case SystemTray::TrayAction::SoundEffect:
      {
        RegistryManager registry;
        bool currentValue = system_tray_->GetSoundEffect();
        registry.SetSoundEffect(currentValue);

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
      break;

    case SystemTray::TrayAction::ProxyService:
      {
        RegistryManager registry;
        registry.SetServiceMode(0);
        bool currentState = system_tray_->GetProxyService();
        registry.SetProxyService(currentState);
      }
      break;

    case SystemTray::TrayAction::SystemProxy:
      {
        RegistryManager registry;
        registry.SetServiceMode(1);
      }
      break;

    case SystemTray::TrayAction::VPNMode:
      {
        RegistryManager registry;
        registry.SetServiceMode(2);
      }
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

    case SystemTray::TrayAction::ConnectionStatusClick:
      ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      if (flutter_controller_) {
        auto messenger = flutter_controller_->engine()->messenger();
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "com.defyx.vpn",
            &flutter::StandardMethodCodec::GetInstance());

        flutter::EncodableMap args;
        std::wstring wideStatus = system_tray_->GetConnectionStatus();

        int size_needed = WideCharToMultiByte(CP_UTF8, 0, wideStatus.c_str(),
                                             (int)wideStatus.length(), NULL, 0, NULL, NULL);
        std::string statusStr(size_needed, 0);
        WideCharToMultiByte(CP_UTF8, 0, wideStatus.c_str(), (int)wideStatus.length(),
                           &statusStr[0], size_needed, NULL, NULL);

        args[flutter::EncodableValue("status")] = flutter::EncodableValue(statusStr);
        channel->InvokeMethod("handleConnectionStatusClick",
                             std::make_unique<flutter::EncodableValue>(args));
      }
      break;

    case SystemTray::TrayAction::Exit:
      DestroyWindow(hwnd);
      break;
  }
}


