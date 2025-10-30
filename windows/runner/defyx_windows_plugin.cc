#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <windows.h>

#include "defyx_core.h"

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;

// Forward declaration
class DefyxWindowsPlugin;

// Custom stream handler for status events
class StatusStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  explicit StatusStreamHandler(DefyxWindowsPlugin* plugin) : plugin_(plugin) {}

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;

 private:
  DefyxWindowsPlugin* plugin_;
};

// Custom stream handler for progress events
class ProgressStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  explicit ProgressStreamHandler(DefyxWindowsPlugin* plugin) : plugin_(plugin) {}

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;

 private:
  DefyxWindowsPlugin* plugin_;
};

class DefyxWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "com.defyx.vpn",
        &flutter::StandardMethodCodec::GetInstance());

    auto status_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
        registrar->messenger(), "com.defyx.vpn_events",
        &flutter::StandardMethodCodec::GetInstance());

    auto progress_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
        registrar->messenger(), "com.defyx.progress_events",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<DefyxWindowsPlugin>(registrar);

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const flutter::MethodCall<flutter::EncodableValue>& call,
                                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    auto status_handler = std::make_unique<StatusStreamHandler>(plugin.get());
    status_channel->SetStreamHandler(std::move(status_handler));

    auto progress_handler = std::make_unique<ProgressStreamHandler>(plugin.get());
    progress_channel->SetStreamHandler(std::move(progress_handler));

    registrar->AddPlugin(std::move(plugin));
    // Note: channels will be destroyed with registrar and plugin
  }

  explicit DefyxWindowsPlugin(flutter::PluginRegistrarWindows* registrar) : registrar_(registrar) {}

  virtual ~DefyxWindowsPlugin() = default;

  void SetStatusSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink) {
    status_sink_ = std::move(sink);
  }
  void ClearStatusSink() { status_sink_.reset(); }

  void SetProgressSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink) {
    progress_sink_ = std::move(sink);
  }
  void ClearProgressSink() { progress_sink_.reset(); }

  void SendStatus(const std::string& status) {
    if (!status_sink_) return;
    EncodableMap map;
    map[EncodableValue("status")] = EncodableValue(status);
    status_sink_->Success(EncodableValue(map));
  }

  void SendProgress(const std::string& msg) {
    if (!progress_sink_) return;
    progress_sink_->Success(EncodableValue(msg));
  }

  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string method = call.method_name();
    defyx_core::LogMessage(std::string("WindowsPlugin Method: ") + method);
    if (method == "connect") {
      // On Windows, just return true and send status
      SendStatus("connecting");
      SendStatus("connected");
      result->Success(flutter::EncodableValue(true));
    } else if (method == "disconnect") {
      bool ok = defyx_core::StopVPN();
      SendStatus(ok ? "disconnected" : "disconnect_failed");
      result->Success(flutter::EncodableValue(ok));
    } else if (method == "prepare") {
      result->Success(flutter::EncodableValue(true));
    } else if (method == "startTun2socks") {
      result->Success(flutter::EncodableValue());
    } else if (method == "getVpnStatus") {
      result->Success(flutter::EncodableValue(defyx_core::GetVpnStatus()));
    } else if (method == "stopTun2Socks") {
      defyx_core::StopTun2Socks();
      result->Success(flutter::EncodableValue(true));
    } else if (method == "calculatePing") {
      long long ping = defyx_core::MeasurePing();
      result->Success(flutter::EncodableValue(ping));
    } else if (method == "getFlag") {
      result->Success(flutter::EncodableValue(defyx_core::GetFlag()));
    } else if (method == "startVPN") {

      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      std::string flowLine, pattern, cacheDir;
      if (args) {
        auto it = args->find(EncodableValue("flowLine"));
        if (it != args->end()) flowLine = std::get<std::string>(it->second);
        it = args->find(EncodableValue("pattern"));
        if (it != args->end()) pattern = std::get<std::string>(it->second);
      }

      cacheDir = "C:/defyx/cache";
      bool ok = defyx_core::StartVPN(cacheDir, flowLine, pattern);
      SendStatus(ok ? "connected" : "disconnected");
      result->Success(flutter::EncodableValue(ok));
    } else if (method == "loadCore") {

      const auto* arg = std::get_if<std::string>(call.arguments());
      std::wstring wpath;
      if (arg) {
        std::string s = *arg;
        int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, NULL, 0);
        if (len > 0) {
          std::wstring buf(len, 0);
          MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, &buf[0], len);
          if (!buf.empty() && buf.back() == L'\0') buf.pop_back();
          wpath = buf;
        }
      }
      bool loaded = defyx_core::LoadCoreDll(wpath);
      result->Success(flutter::EncodableValue(loaded));
    } else if (method == "unloadCore") {
      defyx_core::LogMessage("Unload core requested");
      defyx_core::UnloadCoreDll();
      result->Success(flutter::EncodableValue(true));
    } else if (method == "stopVPN") {
      defyx_core::LogMessage("StopVPN requested via method channel");
      bool ok = defyx_core::StopVPN();
      SendStatus("disconnected");
      result->Success(flutter::EncodableValue(ok));
    } else if (method == "grantVpnPermission") {

      result->Success(flutter::EncodableValue(true));
    } else if (method == "setAsnName") {
      defyx_core::SetAsnName();
      result->Success(flutter::EncodableValue(std::string("success")));
    } else if (method == "setTimezone") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (args) {
        auto it = args->find(EncodableValue("timezone"));
        if (it != args->end()) {
          try {
            auto tzs = std::get<std::string>(it->second);
            float tz = std::stof(tzs);
            defyx_core::SetTimeZone(tz);
            result->Success(flutter::EncodableValue(true));
            return;
          } catch (...) {}
        }
      }
      result->Error("INVALID_ARGUMENT", "timezone missing or invalid");
    } else if (method == "getFlowLine") {
      defyx_core::LogMessage("getFlowLine requested via method channel");
      result->Success(flutter::EncodableValue(defyx_core::GetFlowLine()));
    } else {
      result->NotImplemented();
    }
  }

 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink_;
};

// Stream handler implementations
std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
StatusStreamHandler::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  plugin_->SetStatusSink(std::move(events));
  defyx_core::LogMessage("Status event stream: OnListen");
  plugin_->SendStatus("disconnected");
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
StatusStreamHandler::OnCancelInternal(const flutter::EncodableValue* arguments) {
  plugin_->ClearStatusSink();
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
ProgressStreamHandler::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  plugin_->SetProgressSink(std::move(events));
  defyx_core::LogMessage("Progress event stream: OnListen");
  
  // Forward DLL progress messages to Flutter stream
  defyx_core::RegisterProgressHandler([this](std::string msg) {
    plugin_->SendProgress(msg);
  });
  
  // Enable verbose logging when progress stream is active. debug only
  defyx_core::EnableVerboseLogs(true);
  
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
ProgressStreamHandler::OnCancelInternal(const flutter::EncodableValue* arguments) {
  plugin_->ClearProgressSink();
  defyx_core::RegisterProgressHandler(nullptr);
  defyx_core::EnableVerboseLogs(false);
  return nullptr;
}

}  // namespace


void RegisterDefyxWindowsPlugin(flutter::PluginRegistrarWindows* registrar) {
  DefyxWindowsPlugin::RegisterWithRegistrar(registrar);
}
