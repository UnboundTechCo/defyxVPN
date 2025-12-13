#ifndef RUNNER_SYSTEM_TRAY_H_
#define RUNNER_SYSTEM_TRAY_H_

#include <gtk/gtk.h>
#include <libayatana-appindicator/app-indicator.h>
#include <functional>
#include <string>
#include <memory>

class SystemTray
{
public:
    enum class TrayIconStatus
    {
        Standby,
        Connected,
        Connecting,
        Failed,
        KillSwitch,
        NoInternet
    };

    enum class ConnectionStatus
    {
        Connect,
        Disconnect,
        Connecting,
        Disconnecting,
        Error
    };

    enum class TrayAction
    {
        ShowWindow,
        ToggleWindow,
        Exit,
        LaunchOnStartup,
        AutoConnect,
        StartMinimized,
        ForceClose,
        SoundEffect,
        ProxyService,
        SystemProxy,
        VPNMode,
        OpenIntroduction,
        OpenSpeedTest,
        OpenLogs,
        OpenPreferences,
        ConnectionStatusClick
    };

    using ActionCallback = std::function<void(TrayAction)>;

    SystemTray();
    ~SystemTray();

    bool Initialize(GtkWindow *window, ActionCallback callback);
    void Cleanup();
    void UpdateTooltip(const std::string &tooltip);
    void UpdateIcon(TrayIconStatus status);
    void UpdateConnectionStatus(ConnectionStatus status);
    void SetLaunchOnStartup(bool value);
    void SetAutoConnect(bool value);
    void SetStartMinimized(bool value);
    void SetForceClose(bool value);
    void SetSoundEffect(bool value);
    void SetProxyService(bool value);
    void SetSystemProxy(bool value);
    void SetVPNMode(bool value);
    bool GetAutoConnect() const { return auto_connect_; }
    bool GetStartMinimized() const { return start_minimized_; }
    bool GetForceClose() const { return force_close_; }
    bool GetSoundEffect() const { return sound_effect_; }
    bool GetProxyService() const { return proxy_service_; }
    bool GetSystemProxy() const { return system_proxy_; }
    bool GetVPNMode() const { return vpn_mode_; }
    ConnectionStatus GetConnectionStatus() const { return connection_status_; }
    std::string GetConnectionStatusText() const;
    bool IsVPNDisconnected() const;
    void RebuildMenu();

private:
    void CreateIndicator();
    GtkWidget *CreateMenu();
    void ExecuteAction(TrayAction action);
    std::string GetIconPath(TrayIconStatus status) const;
    std::string GetIconName(TrayIconStatus status) const;
    static std::string ConnectionStatusToString(ConnectionStatus status);

    // GTK callbacks
    static void OnMenuItemActivated(GtkMenuItem *menu_item, gpointer user_data);

    GtkWindow *window_;
    AppIndicator *indicator_;
    GtkWidget *menu_;
    ActionCallback callback_;
    bool initialized_;
    std::string exe_dir_;
    std::string icon_dir_;
    TrayIconStatus current_icon_status_;

    // Checkbox states
    bool launch_on_startup_;
    bool auto_connect_;
    bool start_minimized_;
    bool force_close_;
    bool sound_effect_;
    bool proxy_service_;
    bool system_proxy_;
    bool vpn_mode_;
    ConnectionStatus connection_status_;
};

#endif // RUNNER_SYSTEM_TRAY_H_
