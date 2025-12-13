#pragma once

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <functional>
#include <memory>
#include <string>
#include <mutex>
#include <atomic>

class SystemTray;

class VPNChannelHandler
{
public:
    VPNChannelHandler(FlBinaryMessenger *messenger,
                      GtkWindow *window,
                      SystemTray *system_tray);
    ~VPNChannelHandler();

    void SetupChannels();

    std::string GetVPNStatus() const { return vpn_status_; }
    void SetVPNStatus(const std::string &status);

    void HandleProgressMessage(const std::string &message);
    void SendStatus(const std::string &status);
    void SendProgress(const std::string &message);

private:
    static void HandleMethodCall(FlMethodChannel *channel,
                                 FlMethodCall *method_call,
                                 gpointer user_data);
    static FlMethodErrorResponse *StatusListen(FlEventChannel *channel,
                                               FlValue *args,
                                               gpointer user_data);
    static FlMethodErrorResponse *StatusCancel(FlEventChannel *channel,
                                               FlValue *args,
                                               gpointer user_data);
    static FlMethodErrorResponse *ProgressListen(FlEventChannel *channel,
                                                 FlValue *args,
                                                 gpointer user_data);
    static FlMethodErrorResponse *ProgressCancel(FlEventChannel *channel,
                                                 FlValue *args,
                                                 gpointer user_data);

    void SetupStatusChannel();
    void SetupProgressChannel();
    void SetupMethodChannel();

    FlBinaryMessenger *messenger_;
    SystemTray *system_tray_;

    std::string vpn_status_;
    std::mutex status_mutex_;
    std::atomic<bool> is_active_{true};

    FlMethodChannel *method_channel_;
    FlEventChannel *status_channel_;
    FlEventChannel *progress_channel_;

    bool status_listening_;
    bool progress_listening_;
};
