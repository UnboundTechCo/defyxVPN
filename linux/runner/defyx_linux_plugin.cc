#include <flutter_linux/flutter_linux.h>

#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <chrono>
#include <memory>

#include "defyx_core.h"
#include "proxy_manager.h"

namespace {

constexpr int PING_TIMEOUT_MS = 5000;
constexpr int FLAG_TIMEOUT_MS = 3000;
constexpr const char* DEFAULT_FLAG = "xx";
constexpr int DEFAULT_PING = 999;

struct AsyncPingTask {
  FlMethodCall* method_call;
  
  AsyncPingTask(FlMethodCall* call) : method_call(call) {
    g_object_ref(method_call);
  }
  
  ~AsyncPingTask() {
    if (method_call) {
      g_object_unref(method_call);
    }
  }
};

struct AsyncFlagTask {
  FlMethodCall* method_call;
  
  AsyncFlagTask(FlMethodCall* call) : method_call(call) {
    g_object_ref(method_call);
  }
  
  ~AsyncFlagTask() {
    if (method_call) {
      g_object_unref(method_call);
    }
  }
};

void ProxyCleanupAtExit() {
  proxy::ResetSystemProxy();
}

struct PluginState {
  FlMethodChannel* method_channel = nullptr;
  FlEventChannel* status_channel = nullptr;
  FlEventChannel* progress_channel = nullptr;
  bool status_listening = false;
  bool progress_listening = false;
};

PluginState g_state;

PluginState* GetState(gpointer user_data) {
  return static_cast<PluginState*>(user_data);
}

std::string LookupString(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return {};
  }
  FlValue* value = fl_value_lookup_string(map, key);
  if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(value);
  }
  return {};
}

void SendStatus(PluginState* state, const std::string& status) {
  if (!state->status_listening || state->status_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) payload = fl_value_new_map();
  fl_value_set_string_take(payload, "status", fl_value_new_string(status.c_str()));
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(state->status_channel, payload, nullptr, &error)) {
    g_warning("Failed to send status event: %s", error->message);
  }
}

void SendProgress(PluginState* state, const std::string& message) {
  if (!state->progress_listening || state->progress_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) value = fl_value_new_string(message.c_str());
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(state->progress_channel, value, nullptr, &error)) {
    g_warning("Failed to send progress event: %s", error->message);
  }
}

void FinishWithResponse(FlMethodCall* method_call, FlMethodResponse* response) {
  if (method_call == nullptr || response == nullptr) {
    g_warning("FinishWithResponse called with null parameters");
    return;
  }
  
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send Flutter response: %s", error ? error->message : "unknown error");
  }
}

void FinishWithSuccess(FlMethodCall* method_call, FlValue* result) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  FinishWithResponse(method_call, response);
}

void FinishWithBool(FlMethodCall* method_call, bool value) {
  FinishWithSuccess(method_call, fl_value_new_bool(value));
}

void FinishWithString(FlMethodCall* method_call, const std::string& value) {
  FinishWithSuccess(method_call, fl_value_new_string(value.c_str()));
}

void FinishWithInt(FlMethodCall* method_call, int64_t value) {
  FinishWithSuccess(method_call, fl_value_new_int(value));
}void FinishWithNull(FlMethodCall* method_call) {
  FinishWithSuccess(method_call, fl_value_new_null());
}

void FinishWithError(FlMethodCall* method_call,
                     const char* code,
                     const char* message) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
  FinishWithResponse(method_call, response);
}

void FinishNotImplemented(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  FinishWithResponse(method_call, response);
}

gboolean DeliverPingResult(gpointer user_data) {
  auto* data = static_cast<std::pair<AsyncPingTask*, int>*>(user_data);
  auto* task = data->first;
  int ping_result = data->second;
  
  FinishWithInt(task->method_call, static_cast<int64_t>(ping_result));
  
  delete task;
  delete data;
  return FALSE;
}

gboolean DeliverFlagResult(gpointer user_data) {
  auto* data = static_cast<std::pair<AsyncFlagTask*, std::string>*>(user_data);
  auto* task = data->first;
  std::string flag_result = data->second;
  
  FinishWithString(task->method_call, flag_result);
  
  delete task;
  delete data;
  return FALSE;
}

void ExecutePingInBackground(AsyncPingTask* task) {
  int ping_result = DEFAULT_PING;
  
  try {
    auto start_time = std::chrono::steady_clock::now();
    long long core_ping = defyx_core::MeasurePing();
    auto end_time = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    
    if (duration.count() > PING_TIMEOUT_MS) {
      ping_result = DEFAULT_PING;
    }
    else if (core_ping <= 0) {
      ping_result = DEFAULT_PING;
    }
    else if (core_ping > 9999) {
      ping_result = 9999;
    }
    else {
      ping_result = static_cast<int>(core_ping);
    }
    
  } catch (const std::exception& e) {
    ping_result = DEFAULT_PING;
  } catch (...) {
    ping_result = DEFAULT_PING;
  }
  
  auto* result_data = new std::pair<AsyncPingTask*, int>(task, ping_result);
  g_idle_add(DeliverPingResult, result_data);
}

void ExecuteFlagInBackground(AsyncFlagTask* task) {
  std::string flag_result = DEFAULT_FLAG;
  
  try {
    auto start_time = std::chrono::steady_clock::now();
    std::string core_flag = defyx_core::GetFlag();
    auto end_time = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    
    if (duration.count() > FLAG_TIMEOUT_MS) {
      flag_result = DEFAULT_FLAG;
    }
    else if (core_flag.empty() || core_flag.length() > 10) {
      flag_result = DEFAULT_FLAG;
    }
    else {
      flag_result = core_flag;
    }
    
  } catch (const std::exception& e) {
    flag_result = DEFAULT_FLAG;
  } catch (...) {
    flag_result = DEFAULT_FLAG;
  }
  
  auto* result_data = new std::pair<AsyncFlagTask*, std::string>(task, flag_result);
  g_idle_add(DeliverFlagResult, result_data);
}

void HandleMethodCall(FlMethodChannel* channel,
                      FlMethodCall* method_call,
                      gpointer user_data) {
  PluginState* state = GetState(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  try {
    if (strcmp(method, "connect") == 0) {
      SendStatus(state, "connecting");
      SendStatus(state, "connected");
      FinishWithBool(method_call, true);
    } else if (strcmp(method, "disconnect") == 0) {
      bool ok = defyx_core::StopVPN();
      SendStatus(state, ok ? "disconnected" : "disconnect_failed");
      FinishWithBool(method_call, ok);
    } else if (strcmp(method, "prepare") == 0) {
      FinishWithBool(method_call, true);
    } else if (strcmp(method, "startTun2socks") == 0) {
      defyx_core::StartTun2Socks(0, "127.0.0.1:0");
      FinishWithNull(method_call);
    } else if (strcmp(method, "getVpnStatus") == 0) {
      std::string status = defyx_core::GetVpnStatus();
      if (status.empty()) {
        status = "disconnected";
      }
      FinishWithString(method_call, status);
    } else if (strcmp(method, "isTunnelRunning") == 0) {
      FinishWithBool(method_call, defyx_core::IsTunnelRunning());
    } else if (strcmp(method, "stopTun2Socks") == 0) {
      defyx_core::StopTun2Socks();
      FinishWithBool(method_call, true);
    } else if (strcmp(method, "calculatePing") == 0) {
      auto* ping_task = new AsyncPingTask(method_call);
      std::thread(ExecutePingInBackground, ping_task).detach();
    } else if (strcmp(method, "getFlag") == 0) {
      auto* flag_task = new AsyncFlagTask(method_call);
      std::thread(ExecuteFlagInBackground, flag_task).detach();
    } else if (strcmp(method, "startVPN") == 0) {
      FlValue* args = fl_method_call_get_args(method_call);
      std::string flowLine = LookupString(args, "flowLine");
      std::string pattern = LookupString(args, "pattern");
      
      if (flowLine.empty() || pattern.empty()) {
        FinishWithError(method_call, "INVALID_ARGUMENT", "flowLine or pattern is missing");
        return;
      }
      
      const std::string cacheDir = "/tmp/defyx/cache";
      bool ok = defyx_core::StartVPN(cacheDir, flowLine, pattern);
      SendStatus(state, ok ? "connected" : "disconnected");
      FinishWithBool(method_call, ok);
    } else if (strcmp(method, "loadCore") == 0) {
      FlValue* args = fl_method_call_get_args(method_call);
      std::string path;
      if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
        path = fl_value_get_string(args);
      }
      FinishWithBool(method_call, defyx_core::LoadCoreDll(path));
    } else if (strcmp(method, "unloadCore") == 0) {
      defyx_core::LogMessage("Unload core requested");
      defyx_core::UnloadCoreDll();
      FinishWithBool(method_call, true);
    } else if (strcmp(method, "stopVPN") == 0) {
      defyx_core::LogMessage("StopVPN requested via method channel");
      bool ok = defyx_core::StopVPN();
      SendStatus(state, "disconnected");
      FinishWithBool(method_call, ok);
    } else if (strcmp(method, "grantVpnPermission") == 0) {
      FinishWithBool(method_call, true);
    } else if (strcmp(method, "setAsnName") == 0) {
      defyx_core::SetAsnName();
      FinishWithString(method_call, "success");
    } else if (strcmp(method, "setTimezone") == 0) {
      FlValue* args = fl_method_call_get_args(method_call);
      std::string tz_string = LookupString(args, "timezone");
      if (!tz_string.empty()) {
        try {
          float tz = std::stof(tz_string);
          defyx_core::SetTimeZone(tz);
          FinishWithBool(method_call, true);
          return;
        } catch (...) {
          // Fall through to error
        }
      }
      FinishWithError(method_call, "INVALID_ARGUMENT", "timezone missing or invalid");
    } else if (strcmp(method, "getFlowLine") == 0) {
      std::string flowLine = defyx_core::GetFlowLine();
      if (flowLine.empty()) {
        flowLine = "{}";
      }
      FinishWithString(method_call, flowLine);
    } else if (strcmp(method, "setConnectionMethod") == 0) {
      FlValue* args = fl_method_call_get_args(method_call);
      std::string method_name = LookupString(args, "method");
      if (!method_name.empty()) {
        defyx_core::SetConnectionMethod(method_name);
        FinishWithBool(method_call, true);
      } else {
        FinishWithError(method_call, "INVALID_ARGUMENT", "method parameter missing");
      }
    } else if (strcmp(method, "setSystemProxy") == 0) {
      FlValue* args = fl_method_call_get_args(method_call);
      std::string host = LookupString(args, "host");
      std::string scheme = LookupString(args, "scheme");
      std::string no_proxy = LookupString(args, "noProxy");
      int port = 0;
      
      if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
        FlValue* value = fl_value_lookup_string(args, "port");
        if (value != nullptr) {
          if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
            port = static_cast<int>(fl_value_get_int(value));
          } else if (fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
            port = std::atoi(fl_value_get_string(value));
          }
        }
      }

      if (host.empty() || port <= 0 || port > 65535) {
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
    } else if (strcmp(method, "resetSystemProxy") == 0) {
      proxy::ResetSystemProxy();
      FinishWithBool(method_call, true);
    } else {
      FinishNotImplemented(method_call);
    }
  } catch (const std::exception& e) {
    FinishWithError(method_call, "INTERNAL_ERROR", "Method execution failed");
  } catch (...) {
    FinishWithError(method_call, "INTERNAL_ERROR", "Unknown error occurred");
  }
}

FlMethodErrorResponse* StatusListen(FlEventChannel* channel,
                                    FlValue* args,
                                    gpointer user_data) {
  PluginState* state = GetState(user_data);
  state->status_listening = true;
  defyx_core::LogMessage("Status event stream: OnListen");
  SendStatus(state, "disconnected");
  return nullptr;
}

FlMethodErrorResponse* StatusCancel(FlEventChannel* channel,
                                    FlValue* args,
                                    gpointer user_data) {
  PluginState* state = GetState(user_data);
  state->status_listening = false;
  return nullptr;
}

FlMethodErrorResponse* ProgressListen(FlEventChannel* channel,
                                      FlValue* args,
                                      gpointer user_data) {
  PluginState* state = GetState(user_data);
  state->progress_listening = true;
  defyx_core::LogMessage("Progress event stream: OnListen");
  
  defyx_core::RegisterProgressHandler([state](std::string msg) {
    g_idle_add([](gpointer data) -> gboolean {
      auto* msg_data = static_cast<std::pair<PluginState*, std::string>*>(data);
      SendProgress(msg_data->first, msg_data->second);
      delete msg_data;
      return FALSE;
    }, new std::pair<PluginState*, std::string>(state, msg));
  });
  
  defyx_core::EnableVerboseLogs(true);
  return nullptr;
}

FlMethodErrorResponse* ProgressCancel(FlEventChannel* channel,
                                      FlValue* args,
                                      gpointer user_data) {
  PluginState* state = GetState(user_data);
  state->progress_listening = false;
  defyx_core::RegisterProgressHandler(nullptr);
  defyx_core::EnableVerboseLogs(false);
  return nullptr;
}

}  // namespace

void RegisterDefyxLinuxPlugin(FlPluginRegistrar* registrar) {
  static bool proxy_cleanup_registered = false;
  if (!proxy_cleanup_registered) {
    proxy::RestorePendingSnapshot();
    std::atexit(ProxyCleanupAtExit);
    proxy_cleanup_registered = true;
  }

  PluginState* state = &g_state;

  if (state->method_channel != nullptr) {
    g_object_unref(state->method_channel);
    state->method_channel = nullptr;
  }
  if (state->status_channel != nullptr) {
    g_object_unref(state->status_channel);
    state->status_channel = nullptr;
  }
  if (state->progress_channel != nullptr) {
    g_object_unref(state->progress_channel);
    state->progress_channel = nullptr;
  }

  state->status_listening = false;
  state->progress_listening = false;

  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);

  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    state->method_channel =
        fl_method_channel_new(messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));
  }
  fl_method_channel_set_method_call_handler(state->method_channel,
                                            HandleMethodCall, state, nullptr);

  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    state->status_channel = fl_event_channel_new(
        messenger, "com.defyx.vpn_events", FL_METHOD_CODEC(codec));
  }
  fl_event_channel_set_stream_handlers(state->status_channel, StatusListen,
                                       StatusCancel, state, nullptr);

  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    state->progress_channel = fl_event_channel_new(
        messenger, "com.defyx.progress_events", FL_METHOD_CODEC(codec));
  }
  fl_event_channel_set_stream_handlers(state->progress_channel, ProgressListen,
                                       ProgressCancel, state, nullptr);
}