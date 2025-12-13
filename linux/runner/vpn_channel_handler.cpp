#include "vpn_channel_handler.h"

#include <thread>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <system_error>

#include "defyx_core.h"
#include "proxy_manager.h"
#include "system_tray.h"

namespace
{

    constexpr int PING_TIMEOUT_MS = 5000;
    constexpr int FLAG_TIMEOUT_MS = 3000;
    constexpr const char *DEFAULT_FLAG = "xx";
    constexpr int DEFAULT_PING = 999;

    std::string LookupString(FlValue *map, const char *key)
    {
        if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP)
        {
            return {};
        }
        FlValue *value = fl_value_lookup_string(map, key);
        if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING)
        {
            return fl_value_get_string(value);
        }
        return {};
    }

    void FinishWithResponse(FlMethodCall *method_call, FlMethodResponse *response)
    {
        if (method_call == nullptr || response == nullptr)
        {
            g_warning("FinishWithResponse called with null parameters");
            return;
        }

        g_autoptr(GError) error = nullptr;
        if (!fl_method_call_respond(method_call, response, &error))
        {
            g_warning("Failed to send Flutter response: %s", error ? error->message : "unknown error");
        }
    }

    void FinishWithSuccess(FlMethodCall *method_call, FlValue *result)
    {
        g_autoptr(FlMethodResponse) response =
            FL_METHOD_RESPONSE(fl_method_success_response_new(result));
        FinishWithResponse(method_call, response);
    }

    void FinishWithBool(FlMethodCall *method_call, bool value)
    {
        FinishWithSuccess(method_call, fl_value_new_bool(value));
    }

    void FinishWithString(FlMethodCall *method_call, const std::string &value)
    {
        FinishWithSuccess(method_call, fl_value_new_string(value.c_str()));
    }

    void FinishWithInt(FlMethodCall *method_call, int64_t value)
    {
        FinishWithSuccess(method_call, fl_value_new_int(value));
    }

    void FinishWithNull(FlMethodCall *method_call)
    {
        FinishWithSuccess(method_call, fl_value_new_null());
    }

    void FinishWithError(FlMethodCall *method_call,
                         const char *code,
                         const char *message)
    {
        g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
            fl_method_error_response_new(code, message, nullptr));
        FinishWithResponse(method_call, response);
    }

    void FinishNotImplemented(FlMethodCall *method_call)
    {
        g_autoptr(FlMethodResponse) response =
            FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
        FinishWithResponse(method_call, response);
    }

    struct AsyncPingTask
    {
        FlMethodCall *method_call;

        AsyncPingTask(FlMethodCall *call) : method_call(call)
        {
            g_object_ref(method_call);
        }

        ~AsyncPingTask()
        {
            if (method_call)
            {
                g_object_unref(method_call);
            }
        }
    };

    struct AsyncFlagTask
    {
        FlMethodCall *method_call;

        AsyncFlagTask(FlMethodCall *call) : method_call(call)
        {
            g_object_ref(method_call);
        }

        ~AsyncFlagTask()
        {
            if (method_call)
            {
                g_object_unref(method_call);
            }
        }
    };

    gboolean DeliverPingResult(gpointer user_data)
    {
        auto *data = static_cast<std::pair<AsyncPingTask *, int> *>(user_data);
        auto *task = data->first;
        int ping_result = data->second;

        FinishWithInt(task->method_call, static_cast<int64_t>(ping_result));

        delete task;
        delete data;
        return FALSE;
    }

    gboolean DeliverFlagResult(gpointer user_data)
    {
        auto *data = static_cast<std::pair<AsyncFlagTask *, std::string> *>(user_data);
        auto *task = data->first;
        std::string flag_result = data->second;

        FinishWithString(task->method_call, flag_result);

        delete task;
        delete data;
        return FALSE;
    }

    void ExecutePingInBackground(AsyncPingTask *task)
    {
        int ping_result = DEFAULT_PING;

        try
        {
            auto start_time = std::chrono::steady_clock::now();
            long long core_ping = defyx_core::MeasurePing();
            auto end_time = std::chrono::steady_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);

            if (duration.count() > PING_TIMEOUT_MS)
            {
                ping_result = DEFAULT_PING;
            }
            else if (core_ping <= 0)
            {
                ping_result = DEFAULT_PING;
            }
            else if (core_ping > 9999)
            {
                ping_result = 9999;
            }
            else
            {
                ping_result = static_cast<int>(core_ping);
            }
        }
        catch (...)
        {
            ping_result = DEFAULT_PING;
        }

        auto *result_data = new std::pair<AsyncPingTask *, int>(task, ping_result);
        g_idle_add(DeliverPingResult, result_data);
    }

    void ExecuteFlagInBackground(AsyncFlagTask *task)
    {
        std::string flag_result = DEFAULT_FLAG;

        try
        {
            auto start_time = std::chrono::steady_clock::now();
            std::string core_flag = defyx_core::GetFlag();
            auto end_time = std::chrono::steady_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);

            if (duration.count() > FLAG_TIMEOUT_MS)
            {
                flag_result = DEFAULT_FLAG;
            }
            else if (core_flag.empty() || core_flag.length() > 10)
            {
                flag_result = DEFAULT_FLAG;
            }
            else
            {
                flag_result = core_flag;
            }
        }
        catch (...)
        {
            flag_result = DEFAULT_FLAG;
        }

        auto *result_data = new std::pair<AsyncFlagTask *, std::string>(task, flag_result);
        g_idle_add(DeliverFlagResult, result_data);
    }

} // namespace

VPNChannelHandler::VPNChannelHandler(FlBinaryMessenger *messenger,
                                     GtkWindow * /*window*/,
                                     SystemTray *system_tray)
    : messenger_(messenger),
      system_tray_(system_tray),
      vpn_status_("disconnected"),
      method_channel_(nullptr),
      status_channel_(nullptr),
      progress_channel_(nullptr),
      status_listening_(false),
      progress_listening_(false) {}

VPNChannelHandler::~VPNChannelHandler()
{
    is_active_ = false;

    if (method_channel_)
    {
        g_object_unref(method_channel_);
        method_channel_ = nullptr;
    }
    if (status_channel_)
    {
        g_object_unref(status_channel_);
        status_channel_ = nullptr;
    }
    if (progress_channel_)
    {
        g_object_unref(progress_channel_);
        progress_channel_ = nullptr;
    }
}

void VPNChannelHandler::SetupChannels()
{
    SetupStatusChannel();
    SetupProgressChannel();
    SetupMethodChannel();
}

void VPNChannelHandler::SetupStatusChannel()
{
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    status_channel_ = fl_event_channel_new(
        messenger_, "com.defyx.vpn_events", FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(status_channel_, StatusListen,
                                         StatusCancel, this, nullptr);
}

void VPNChannelHandler::SetupProgressChannel()
{
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    progress_channel_ = fl_event_channel_new(
        messenger_, "com.defyx.progress_events", FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(progress_channel_, ProgressListen,
                                         ProgressCancel, this, nullptr);
}

void VPNChannelHandler::SetupMethodChannel()
{
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    method_channel_ = fl_method_channel_new(messenger_, "com.defyx.vpn",
                                            FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(method_channel_, HandleMethodCall,
                                              this, nullptr);
}

FlMethodErrorResponse *VPNChannelHandler::StatusListen(FlEventChannel *channel,
                                                       FlValue *args,
                                                       gpointer user_data)
{
    VPNChannelHandler *self = static_cast<VPNChannelHandler *>(user_data);
    self->status_listening_ = true;
    defyx_core::LogMessage("VPNChannelHandler: Status event stream - OnListen");
    self->SendStatus("disconnected");
    return nullptr;
}

FlMethodErrorResponse *VPNChannelHandler::StatusCancel(FlEventChannel *channel,
                                                       FlValue *args,
                                                       gpointer user_data)
{
    VPNChannelHandler *self = static_cast<VPNChannelHandler *>(user_data);
    self->status_listening_ = false;
    return nullptr;
}

FlMethodErrorResponse *VPNChannelHandler::ProgressListen(FlEventChannel *channel,
                                                         FlValue *args,
                                                         gpointer user_data)
{
    VPNChannelHandler *self = static_cast<VPNChannelHandler *>(user_data);
    self->progress_listening_ = true;
    defyx_core::LogMessage("VPNChannelHandler: Progress event stream - OnListen");

    defyx_core::RegisterProgressHandler([self](std::string msg)
                                        {
    if (!self->is_active_) return;
    
    g_idle_add([](gpointer data) -> gboolean {
      auto* msg_data = static_cast<std::pair<VPNChannelHandler*, std::string>*>(data);
      msg_data->first->HandleProgressMessage(msg_data->second);
      delete msg_data;
      return FALSE;
    }, new std::pair<VPNChannelHandler*, std::string>(self, msg)); });

    defyx_core::EnableVerboseLogs(true);
    return nullptr;
}

FlMethodErrorResponse *VPNChannelHandler::ProgressCancel(FlEventChannel *channel,
                                                         FlValue *args,
                                                         gpointer user_data)
{
    VPNChannelHandler *self = static_cast<VPNChannelHandler *>(user_data);
    self->progress_listening_ = false;
    defyx_core::RegisterProgressHandler(nullptr);
    defyx_core::EnableVerboseLogs(false);
    return nullptr;
}

void VPNChannelHandler::SetVPNStatus(const std::string &status)
{
    std::lock_guard<std::mutex> lock(status_mutex_);
    vpn_status_ = status;
}

void VPNChannelHandler::SendStatus(const std::string &status)
{
    if (!status_listening_ || status_channel_ == nullptr)
    {
        return;
    }
    g_autoptr(FlValue) payload = fl_value_new_map();
    fl_value_set_string_take(payload, "status", fl_value_new_string(status.c_str()));
    g_autoptr(GError) error = nullptr;
    if (!fl_event_channel_send(status_channel_, payload, nullptr, &error))
    {
        g_warning("Failed to send status event: %s", error->message);
    }
}

void VPNChannelHandler::SendProgress(const std::string &message)
{
    if (!progress_listening_ || progress_channel_ == nullptr)
    {
        return;
    }
    g_autoptr(FlValue) value = fl_value_new_string(message.c_str());
    g_autoptr(GError) error = nullptr;
    if (!fl_event_channel_send(progress_channel_, value, nullptr, &error))
    {
        g_warning("Failed to send progress event: %s", error->message);
    }
}

void VPNChannelHandler::HandleProgressMessage(const std::string &msg)
{
    if (!is_active_)
        return;

    SendProgress(msg);

    if (msg.find("Data: VPN connected") != std::string::npos)
    {
        {
            std::lock_guard<std::mutex> lock(status_mutex_);
            vpn_status_ = "connected";
        }
        SendStatus(vpn_status_);

        if (system_tray_)
        {
            system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connected);
            system_tray_->UpdateTooltip("DefyxVPN - Connected");
            system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Disconnect);
        }

        // Apply system proxy if enabled
        std::thread([this]()
                    {
      if (!is_active_) return;
      if (system_tray_ && system_tray_->GetSystemProxy()) {
        proxy::ProxyConfig config;
        config.host = "127.0.0.1";
        config.port = 1080;
        config.scheme = "socks5";
        proxy::ApplySystemProxy(config);
      } })
            .detach();
    }
    else if (msg.find("Data: VPN failed") != std::string::npos)
    {
        {
            std::lock_guard<std::mutex> lock(status_mutex_);
            vpn_status_ = "disconnected";
        }

        if (system_tray_)
        {
            system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Failed);
            system_tray_->UpdateTooltip("DefyxVPN - Error");
            system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Error);
        }

        std::thread([this]()
                    {
      if (!is_active_) return;
      if (system_tray_ && system_tray_->GetSystemProxy()) {
        proxy::ResetSystemProxy();
      } })
            .detach();

        SendStatus(vpn_status_);
    }
    else if (msg.find("Data: VPN stopped") != std::string::npos ||
             msg.find("Data: VPN cancelled") != std::string::npos)
    {
        {
            std::lock_guard<std::mutex> lock(status_mutex_);
            vpn_status_ = "disconnected";
        }

        if (system_tray_)
        {
            system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
            system_tray_->UpdateTooltip("DefyxVPN - Disconnected");
            system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Connect);
        }

        std::thread([this]()
                    {
      if (!is_active_) return;
      if (system_tray_ && system_tray_->GetSystemProxy()) {
        proxy::ResetSystemProxy();
      } })
            .detach();

        SendStatus(vpn_status_);
    }
}

void VPNChannelHandler::HandleMethodCall(FlMethodChannel *channel,
                                         FlMethodCall *method_call,
                                         gpointer user_data)
{
    VPNChannelHandler *self = static_cast<VPNChannelHandler *>(user_data);
    const gchar *method = fl_method_call_get_name(method_call);

    try
    {
        if (strcmp(method, "connect") == 0)
        {
            self->SetVPNStatus("connected");
            self->SendStatus("connected");
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "disconnect") == 0)
        {
            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                self->vpn_status_ = "disconnecting";
            }

            if (self->system_tray_)
            {
                self->system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Disconnecting);
                self->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connecting);
                self->system_tray_->UpdateTooltip("DefyxVPN - Disconnecting ...");
            }

            self->SendStatus("disconnecting");

            defyx_core::StopVPN();
            defyx_core::Stop();
            std::this_thread::sleep_for(std::chrono::milliseconds(50));

            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                self->vpn_status_ = "disconnected";
            }

            if (self->system_tray_)
            {
                self->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
                self->system_tray_->UpdateTooltip("DefyxVPN - Disconnected");
                self->system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Connect);
            }

            std::thread([self]()
                        {
        if (!self->is_active_) return;
        if (self->system_tray_ && self->system_tray_->GetSystemProxy()) {
          proxy::ResetSystemProxy();
        } })
                .detach();

            self->SendStatus("disconnected");
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "prepareVPN") == 0 || strcmp(method, "grantVpnPermission") == 0)
        {
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "startTun2socks") == 0 || strcmp(method, "stopTun2Socks") == 0)
        {
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "getVpnStatus") == 0)
        {
            std::string status;
            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                status = self->vpn_status_;
            }
            FinishWithString(method_call, status);
        }
        else if (strcmp(method, "isTunnelRunning") == 0)
        {
            std::string status;
            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                status = self->vpn_status_;
            }
            FinishWithBool(method_call, status == "connected");
        }
        else if (strcmp(method, "calculatePing") == 0)
        {
            auto *ping_task = new AsyncPingTask(method_call);
            std::thread(ExecutePingInBackground, ping_task).detach();
        }
        else if (strcmp(method, "getFlag") == 0)
        {
            auto *flag_task = new AsyncFlagTask(method_call);
            std::thread(ExecuteFlagInBackground, flag_task).detach();
        }
        else if (strcmp(method, "setAsnName") == 0)
        {
            defyx_core::SetAsnName();
            FinishWithNull(method_call);
        }
        else if (strcmp(method, "setTimezone") == 0)
        {
            FlValue *args = fl_method_call_get_args(method_call);
            std::string tz_string = LookupString(args, "timezone");
            if (!tz_string.empty())
            {
                try
                {
                    float tz = std::stof(tz_string);
                    defyx_core::SetTimeZone(tz);
                    FinishWithBool(method_call, true);
                    return;
                }
                catch (...)
                {
                    // Fall through to error
                }
            }
            FinishWithError(method_call, "INVALID_ARGUMENT", "timezone missing or invalid");
        }
        else if (strcmp(method, "getFlowLine") == 0)
        {
            FlValue *args = fl_method_call_get_args(method_call);
            std::string is_test_str = LookupString(args, "isTest");
            std::string flowLine = defyx_core::GetFlowLine();
            if (flowLine.empty())
            {
                flowLine = "{}";
            }
            FinishWithString(method_call, flowLine);
        }
        else if (strcmp(method, "setConnectionMethod") == 0)
        {
            FlValue *args = fl_method_call_get_args(method_call);
            std::string method_name = LookupString(args, "method");
            if (!method_name.empty())
            {
                defyx_core::SetConnectionMethod(method_name);
                FinishWithBool(method_call, true);
            }
            else
            {
                FinishWithError(method_call, "INVALID_ARGUMENT", "method parameter missing");
            }
        }
        else if (strcmp(method, "startVPN") == 0)
        {
            FlValue *args = fl_method_call_get_args(method_call);
            std::string flow = LookupString(args, "flowLine");
            std::string pattern = LookupString(args, "pattern");

            std::string cache_dir = "/tmp/defyx/cache";
            std::error_code ec;
            std::filesystem::create_directories(cache_dir, ec);

            defyx_core::StartVPN(cache_dir, flow, pattern);

            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                self->vpn_status_ = "connecting";
            }

            if (self->system_tray_)
            {
                self->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connecting);
                self->system_tray_->UpdateTooltip("DefyxVPN - Connecting ...");
                self->system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Connecting);
            }

            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "stopVPN") == 0)
        {
            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                self->vpn_status_ = "disconnecting";
            }

            if (self->system_tray_)
            {
                self->system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Disconnecting);
                self->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Connecting);
                self->system_tray_->UpdateTooltip("DefyxVPN - Disconnecting ...");
            }

            self->SendStatus("disconnecting");

            defyx_core::StopVPN();
            std::this_thread::sleep_for(std::chrono::milliseconds(50));

            {
                std::lock_guard<std::mutex> lock(self->status_mutex_);
                self->vpn_status_ = "disconnected";
            }

            if (self->system_tray_)
            {
                self->system_tray_->UpdateConnectionStatus(SystemTray::ConnectionStatus::Connect);
                self->system_tray_->UpdateIcon(SystemTray::TrayIconStatus::Standby);
                self->system_tray_->UpdateTooltip("DefyxVPN - Disconnected");
            }

            self->SendStatus("disconnected");
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "isVPNPrepared") == 0)
        {
            FinishWithBool(method_call, true);
        }
        else if (strcmp(method, "setSystemProxy") == 0)
        {
            FlValue *args = fl_method_call_get_args(method_call);
            std::string host = LookupString(args, "host");
            std::string scheme = LookupString(args, "scheme");
            std::string no_proxy = LookupString(args, "noProxy");
            int port = 0;

            if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
            {
                FlValue *value = fl_value_lookup_string(args, "port");
                if (value != nullptr)
                {
                    if (fl_value_get_type(value) == FL_VALUE_TYPE_INT)
                    {
                        port = static_cast<int>(fl_value_get_int(value));
                    }
                    else if (fl_value_get_type(value) == FL_VALUE_TYPE_STRING)
                    {
                        port = std::atoi(fl_value_get_string(value));
                    }
                }
            }

            if (host.empty() || port <= 0 || port > 65535)
            {
                FinishWithError(method_call, "INVALID_ARGUMENT", "Invalid host or port");
                return;
            }

            proxy::ProxyConfig config;
            config.host = host;
            config.port = port;
            config.scheme = scheme.empty() ? "http" : scheme;
            config.no_proxy = no_proxy;
            bool ok = proxy::ApplySystemProxy(config);
            FinishWithBool(method_call, ok);
        }
        else if (strcmp(method, "resetSystemProxy") == 0)
        {
            proxy::ResetSystemProxy();
            FinishWithBool(method_call, true);
        }
        else
        {
            FinishNotImplemented(method_call);
        }
    }
    catch (const std::exception &e)
    {
        FinishWithError(method_call, "INTERNAL_ERROR", "Method execution failed");
    }
    catch (...)
    {
        FinishWithError(method_call, "INTERNAL_ERROR", "Unknown error occurred");
    }
}
