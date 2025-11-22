#include "vpn_channel_handler.h"

#include <thread>
#include "dxcore_bridge.h"
#include "system_tray.h"

VPNChannelHandler::VPNChannelHandler(flutter::BinaryMessenger* messenger,
                                     HWND window_handle,
                                     DXCoreBridge* dxcore,
                                     SystemTray* system_tray)
    : messenger_(messenger),
      window_handle_(window_handle),
      dxcore_(dxcore),
      system_tray_(system_tray),
      vpn_status_("disconnected") {}

VPNChannelHandler::~VPNChannelHandler() {
  status_sink_.reset();
  progress_sink_.reset();
  pending_ping_result_.reset();
}

void VPNChannelHandler::SetupChannels() {
  SetupStatusChannel();
  SetupProgressChannel();
  SetupMethodChannel();
}

void VPNChannelHandler::SetupStatusChannel() {
  class StatusHandler : public flutter::StreamHandler<flutter::EncodableValue> {
   public:
    StatusHandler(VPNChannelHandler* parent) : parent_(parent) {}

   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(const flutter::EncodableValue* arguments,
                     std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
      parent_->status_sink_ = std::move(events);
      return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override {
      parent_->status_sink_.reset();
      return nullptr;
    }

   private:
    VPNChannelHandler* parent_;
  };

  status_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger_, "com.defyx.vpn_events",
      &flutter::StandardMethodCodec::GetInstance());
  status_channel_->SetStreamHandler(std::make_unique<StatusHandler>(this));
}

void VPNChannelHandler::SetupProgressChannel() {
  class ProgressHandler : public flutter::StreamHandler<flutter::EncodableValue> {
   public:
    ProgressHandler(VPNChannelHandler* parent) : parent_(parent) {}

   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(const flutter::EncodableValue* arguments,
                     std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
      parent_->progress_sink_ = std::move(events);

      parent_->dxcore_->SetProgressCallback([this, parent = parent_](const std::string& msg) {

        PostMessage(parent->window_handle_, WM_PROGRESS_RESULT, 0,
                    reinterpret_cast<LPARAM>(new std::string(msg)));

        if (msg.find("Data: VPN connected") != std::string::npos) {
          parent->vpn_status_ = "connected";

          PostMessage(parent->window_handle_, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(parent->vpn_status_)));

          if (parent->system_tray_) {
            parent->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connected);
            parent->system_tray_->UpdateTooltip(L"DefyxVPN - Connected");
            parent->system_tray_->UpdateConnectionStatus(L"\u2714\uFE0F Connected");
          }

          std::thread([parent]() {
            if (parent->system_tray_ && parent->system_tray_->GetSystemProxy()) {
              parent->dxcore_->SetSystemProxy();
            }
          }).detach();
        } else if (msg.find("Data: VPN failed") != std::string::npos) {
          parent->vpn_status_ = "disconnected";

          if (parent->system_tray_) {
            parent->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Failed);
            parent->system_tray_->UpdateTooltip(L"DefyxVPN - Error");
            parent->system_tray_->UpdateConnectionStatus(L"Error");
          }

          std::thread([parent]() {
            if (parent->system_tray_ && parent->system_tray_->GetSystemProxy()) {
              parent->dxcore_->ResetSystemProxy();
            }
          }).detach();

          PostMessage(parent->window_handle_, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(parent->vpn_status_)));
        } else if (msg.find("Data: VPN stopped") != std::string::npos ||
                   msg.find("Data: VPN cancelled") != std::string::npos) {
          parent->vpn_status_ = "disconnected";

          if (parent->system_tray_) {
            parent->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            parent->system_tray_->UpdateTooltip(L"DefyxVPN - Disconnected");
            parent->system_tray_->UpdateConnectionStatus(L"Disconnected");
          }

          std::thread([parent]() {
            if (parent->system_tray_ && parent->system_tray_->GetSystemProxy()) {
              parent->dxcore_->ResetSystemProxy();
            }
          }).detach();

          PostMessage(parent->window_handle_, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(parent->vpn_status_)));
        }
      });

      return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override {
      parent_->progress_sink_.reset();
      return nullptr;
    }

   private:
    VPNChannelHandler* parent_;
  };

  progress_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger_, "com.defyx.progress_events",
      &flutter::StandardMethodCodec::GetInstance());
  progress_channel_->SetStreamHandler(std::make_unique<ProgressHandler>(this));
}

void VPNChannelHandler::SetupMethodChannel() {
  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger_, "com.defyx.vpn",
      &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
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
          vpn_status_ = "connected";
          SendStatus();
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "disconnect") {
          dxcore_->StopVPN();
          dxcore_->Stop();
          vpn_status_ = "disconnected";

          if (system_tray_) {
            system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            system_tray_->UpdateTooltip(L"DefyxVPN - Disconnected");
            system_tray_->UpdateConnectionStatus(L"Disconnected");
          }

          std::thread([this]() {
            if (system_tray_ && system_tray_->GetSystemProxy()) {
              dxcore_->ResetSystemProxy();
            }
          }).detach();

          SendStatus();
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "prepareVPN" || method == "grantVpnPermission") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "startTun2socks" || method == "stopTun2Socks") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "getVpnStatus") {
          result->Success(flutter::EncodableValue(vpn_status_));
          return;
        }

        if (method == "isTunnelRunning") {
          result->Success(flutter::EncodableValue(vpn_status_ == "connected"));
          return;
        }

        if (method == "calculatePing") {
          pending_ping_result_ = std::move(result);

          std::thread([this]() {
            try {
              SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);

              int ping = dxcore_->MeasurePing();

              if (ping < 0) ping = 0;
              if (ping > 9999) ping = 9999;
              if (ping == 0) ping = 100;

              PostMessage(window_handle_, WM_PING_RESULT, 0,
                         static_cast<LPARAM>(ping));

            } catch (...) {
              PostMessage(window_handle_, WM_PING_RESULT, 0,
                         static_cast<LPARAM>(100));
            }
          }).detach();

          return;
        }

        if (method == "getFlag") {
          std::thread([this, result = std::move(result)]() {
            std::string flag = "xx";

            if (vpn_status_ == "connected") {
              flag = dxcore_->GetFlag();

              if (flag.empty()) {
                flag = "xx";
              }
            }

            result->Success(flutter::EncodableValue(flag));
          }).detach();
          return;
        }

        if (method == "setAsnName") {
          dxcore_->SetAsnName();
          result->Success();
          return;
        }

        if (method == "setTimezone") {
          if (call.arguments() && std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
            auto m = std::get<flutter::EncodableMap>(*call.arguments());
            auto tz_str = get_string_arg(m, "timezone");
            try {
              float tz = std::stof(tz_str);
              dxcore_->SetTimeZone(tz);
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
            std::thread([this, is_test, result = std::move(result)]() mutable {
              try {
                std::string fl = dxcore_->GetFlowLine(is_test);
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

            dxcore_->StartVPN(cache_dir, flow, pattern);

            vpn_status_ = "connecting";
            if (system_tray_) {
              system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connecting);
              system_tray_->UpdateTooltip(L"DefyxVPN - Connecting...");
              system_tray_->UpdateConnectionStatus(L"Connecting...");
            }

            result->Success(flutter::EncodableValue(true));
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }

        if (method == "stopVPN") {
          dxcore_->StopVPN();
          vpn_status_ = "disconnected";

          if (system_tray_) {
            system_tray_->UpdateConnectionStatus(L"Disconnected");
            system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            system_tray_->UpdateTooltip(L"DefyxVPN - Disconnected");
          }

          SendStatus();
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (method == "isVPNPrepared") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        result->NotImplemented();
      });
}

void VPNChannelHandler::SendStatus() {
  if (status_sink_) {
    flutter::EncodableMap m;
    m[flutter::EncodableValue("status")] = flutter::EncodableValue(vpn_status_);
    status_sink_->Success(flutter::EncodableValue(m));
  }
}

void VPNChannelHandler::HandlePingResult(int ping_value) {
  if (pending_ping_result_) {
    pending_ping_result_->Success(flutter::EncodableValue(ping_value));
    pending_ping_result_.reset();
  }
}

void VPNChannelHandler::HandleProgressResult(const std::string& message) {
  if (progress_sink_) {
    progress_sink_->Success(flutter::EncodableValue(message));
  }
}

void VPNChannelHandler::HandleStatusResult(const std::string& status) {
  if (status_sink_) {
    flutter::EncodableMap m;
    m[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
    status_sink_->Success(flutter::EncodableValue(m));
  }
}

