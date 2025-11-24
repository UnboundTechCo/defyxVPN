#pragma once

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <string>
#include <windows.h>

class DXCoreBridge;
class SystemTray;

#define WM_PING_RESULT (WM_USER + 2)
#define WM_PROGRESS_RESULT (WM_USER + 3)
#define WM_STATUS_RESULT (WM_USER + 4)

class VPNChannelHandler {
 public:
  VPNChannelHandler(flutter::BinaryMessenger* messenger,
                    HWND window_handle,
                    DXCoreBridge* dxcore,
                    SystemTray* system_tray);
  ~VPNChannelHandler();

  void SetupChannels();

  std::string GetVPNStatus() const { return vpn_status_; }

  void HandlePingResult(int ping_value);
  void HandleProgressResult(const std::string& message);
  void HandleStatusResult(const std::string& status);

 private:
  void SetupStatusChannel();
  void SetupProgressChannel();
  void SetupMethodChannel();

  void SendStatus();

  flutter::BinaryMessenger* messenger_;
  HWND window_handle_;
  DXCoreBridge* dxcore_;
  SystemTray* system_tray_;

  std::string vpn_status_;

  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> status_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> progress_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> progress_sink_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_ping_result_;
};

