#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"
#include "system_tray.h"

class VPNChannelHandler;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         bool tunnel_mode = false);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void HandleTrayAction(SystemTray::TrayAction action);

  flutter::DartProject project_;
  bool tunnel_mode_ = false;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<SystemTray> system_tray_;
  std::unique_ptr<VPNChannelHandler> vpn_channel_handler_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
