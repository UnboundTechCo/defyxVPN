#include "flutter_window.h"

#include <optional>
#include <thread>
#include <memory>

#include "dxcore_bridge.h"
#include "proxy_config.h"
#include "flutter/generated_plugin_registrant.h"
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>


#define WM_FLAG_RESULT (WM_USER + 1)
#define WM_PING_RESULT (WM_USER + 2)
// Marshal background callbacks to the platform thread
#define WM_PROGRESS_RESULT (WM_USER + 3)
#define WM_STATUS_RESULT (WM_USER + 4)

static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> flag_sink;
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink;
static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink;
static std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_ping_result;
static HWND g_window_handle = nullptr;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

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

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // Set up method and event channels for Windows
  auto messenger = flutter_controller_->engine()->messenger();
  // Cache window handle for posting messages from background threads
  g_window_handle = GetHandle();

  // Make bridge global so handlers can access it.
  static DXCoreBridge g_dxcore;
  static ProxyConfig g_proxy;
  if (!g_dxcore.Load()) {
    OutputDebugStringA("[DXcore] Failed to load DXcore.dll\n");
  } else {
    OutputDebugStringA("[DXcore] Successfully loaded DXcore.dll\n");
  }


  static std::string vpn_status = "disconnected";


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


  // Flag result events channel
  class FlagHandler : public flutter::StreamHandler<flutter::EncodableValue> {
   protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(const flutter::EncodableValue* arguments,
                     std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
      flag_sink = std::move(events);
      return nullptr;
    }
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override {
      flag_sink.reset();
      return nullptr;
    }
  };
  auto flag_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "com.defyx.flag_events",
      &flutter::StandardMethodCodec::GetInstance());
  flag_channel->SetStreamHandler(std::make_unique<FlagHandler>());

  // Progress events channel
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
        // Always marshal to platform thread
        PostMessage(g_window_handle, WM_PROGRESS_RESULT, 0,
                    reinterpret_cast<LPARAM>(new std::string(msg)));

        if (msg.find("Data: VPN connected") != std::string::npos) {
          OutputDebugStringA("[DXcore] VPN connected - updating status\n");
          vpn_status = "connected";
          // Emit status on platform thread
          PostMessage(g_window_handle, WM_STATUS_RESULT, 0,
                      reinterpret_cast<LPARAM>(new std::string(vpn_status)));
          

          std::thread([]() {
            OutputDebugStringA("[Proxy] Enabling system proxy on 127.0.0.1:5000\n");
            if (g_proxy.EnableProxy("127.0.0.1:5000")) {
              OutputDebugStringA("[Proxy] System proxy enabled on 127.0.0.1:5000\n");
            } else {
              OutputDebugStringA("[Proxy] Failed to enable system proxy\n");
            }
          }).detach();
        } else if (msg.find("Data: VPN failed") != std::string::npos ||
                   msg.find("Data: VPN stopped") != std::string::npos ||
                   msg.find("Data: VPN cancelled") != std::string::npos) {
          OutputDebugStringA("[DXcore] VPN stopped/failed - updating status to disconnected and disabling proxy\n");
          vpn_status = "disconnected";
          
          // Disable system proxy
          if (g_proxy.DisableProxy()) {
            OutputDebugStringA("[Proxy] System proxy disabled\n");
          } else {
            OutputDebugStringA("[Proxy] Failed to disable system proxy\n");
          }

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
              
              OutputDebugStringA(("[DXcore] Fresh ping measurement: " + std::to_string(ping) + "ms\n").c_str());
              
              // Post the fresh result back to main thread for UI update
              PostMessage(g_window_handle, WM_PING_RESULT, 0, 
                         static_cast<LPARAM>(ping));
              
            } catch (...) {
              OutputDebugStringA("[DXcore] Ping measurement failed\n");
              // Post default value on error
              PostMessage(g_window_handle, WM_PING_RESULT, 0, 
                         static_cast<LPARAM>(100));
            }
          }).detach();
          
          return; // Don't call result->Success() here, we'll call it when ping completes
        }
        if (method == "getFlag") {
          result->Success();
          std::thread([]() {
            std::string* flag_ptr = new std::string(g_dxcore.GetFlag());
            PostMessage(g_window_handle, WM_FLAG_RESULT, 0, reinterpret_cast<LPARAM>(flag_ptr));
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
            auto fl = g_dxcore.GetFlowLine(is_test);
            result->Success(flutter::EncodableValue(fl));
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

            std::string log = "[DXcore] Starting VPN with cache_dir=" + cache_dir + 
                             ", flow=" + flow + ", pattern=" + pattern + "\n";
            OutputDebugStringA(log.c_str());
            
            g_dxcore.StartVPN(cache_dir, flow, pattern);
            // Don't set status to connected immediately - wait for DXcore progress callback
            // vpn_status will be updated by progress handler when "Data: VPN connected" is received
            result->Success(flutter::EncodableValue(true));
          } else {
            result->Error("INVALID_ARGUMENT", "missing args");
          }
          return;
        }
        if (method == "stopVPN") {
          g_dxcore.StopVPN();
          g_proxy.DisableProxy();  // Ensure proxy is disabled
          vpn_status = "disconnected";
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

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
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
    case WM_FLAG_RESULT: {
      std::unique_ptr<std::string> flag_ptr(reinterpret_cast<std::string*>(lparam));
      if (flag_sink) {
        const std::string flag = flag_ptr ? *flag_ptr : std::string();
        flag_sink->Success(flutter::EncodableValue(flag));
      }
      return 0;
    }
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
