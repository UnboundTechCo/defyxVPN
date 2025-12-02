#include "system_tray.h"

// Suppress deprecation warnings for older AppIndicator API
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#include <unistd.h>
#include <limits.h>
#include <cstring>
#include <filesystem>

// Menu item data structure for callbacks
struct MenuItemData
{
    SystemTray *tray;
    SystemTray::TrayAction action;
};

SystemTray::SystemTray()
    : window_(nullptr),
      indicator_(nullptr),
      menu_(nullptr),
      callback_(nullptr),
      initialized_(false),
      current_icon_status_(TrayIconStatus::Standby),
      launch_on_startup_(false),
      auto_connect_(false),
      start_minimized_(false),
      force_close_(true),
      sound_effect_(true),
      proxy_service_(true),
      system_proxy_(false),
      vpn_mode_(false),
      connection_status_(ConnectionStatus::Connect)
{
    // Get executable directory for icon paths
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len != -1)
    {
        exe_path[len] = '\0';
        exe_dir_ = std::filesystem::path(exe_path).parent_path().string();
        icon_dir_ = exe_dir_ + "/data/flutter_assets/assets/icons";
    }
}

SystemTray::~SystemTray()
{
    Cleanup();
}

bool SystemTray::Initialize(GtkWindow *window, ActionCallback callback)
{
    if (initialized_)
    {
        return true;
    }

    window_ = window;
    callback_ = callback;

    CreateIndicator();

    if (!indicator_)
    {
        return false;
    }

    initialized_ = true;
    return true;
}

void SystemTray::CreateIndicator()
{
    // Create the indicator with icon directory path
    std::string icon_name = GetIconName(TrayIconStatus::Standby);

    indicator_ = app_indicator_new(
        "defyx-vpn",
        icon_name.c_str(),
        APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

    if (!indicator_)
    {
        g_warning("Failed to create AppIndicator");
        return;
    }

    // Set the icon theme path to our assets directory
    app_indicator_set_icon_theme_path(indicator_, icon_dir_.c_str());

    // Set indicator status to active
    app_indicator_set_status(indicator_, APP_INDICATOR_STATUS_ACTIVE);

    // Set title/tooltip
    app_indicator_set_title(indicator_, "DefyxVPN");

    // Create and set the menu
    menu_ = CreateMenu();
    app_indicator_set_menu(indicator_, GTK_MENU(menu_));
}

GtkWidget *SystemTray::CreateMenu()
{
    GtkWidget *menu = gtk_menu_new();

    // Helper to add menu items
    auto add_item = [this, menu](const char *label, TrayAction action,
                                 bool is_check = false, bool checked = false,
                                 bool sensitive = true) -> GtkWidget *
    {
        GtkWidget *item;
        if (is_check)
        {
            item = gtk_check_menu_item_new_with_label(label);
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item), checked);
        }
        else
        {
            item = gtk_menu_item_new_with_label(label);
        }

        gtk_widget_set_sensitive(item, sensitive);

        MenuItemData *data = new MenuItemData{this, action};
        g_signal_connect(G_OBJECT(item), "activate",
                         G_CALLBACK(OnMenuItemActivated), data);
        g_object_set_data_full(G_OBJECT(item), "menu-data", data,
                               [](gpointer data)
                               { delete static_cast<MenuItemData *>(data); });

        gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
        return item;
    };

    auto add_separator = [menu]()
    {
        GtkWidget *sep = gtk_separator_menu_item_new();
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep);
    };

    auto add_label = [menu](const char *label)
    {
        GtkWidget *item = gtk_menu_item_new_with_label(label);
        gtk_widget_set_sensitive(item, FALSE);
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    };

    // Main window
    add_item("DefyxVPN", TrayAction::ShowWindow);
    add_separator();

    // Connection status
    std::string status_text = GetConnectionStatusText();
    bool is_transitioning = (connection_status_ == ConnectionStatus::Connecting ||
                             connection_status_ == ConnectionStatus::Disconnecting);
    add_item(status_text.c_str(), TrayAction::ConnectionStatusClick, false, false, !is_transitioning);

    add_item("Preferences", TrayAction::OpenPreferences);
    add_separator();

    // Startup Options section
    add_label("Startup Options");
    add_item("    Launch on startup", TrayAction::LaunchOnStartup, true, launch_on_startup_);
    add_item("    Auto-connect", TrayAction::AutoConnect, true, auto_connect_);
    add_item("    Sound Effect", TrayAction::SoundEffect, true, sound_effect_);
    add_item("    Start minimized", TrayAction::StartMinimized, true, start_minimized_);
    add_item("    Force close", TrayAction::ForceClose, true, force_close_);
    add_separator();

    // Service Mode section
    add_label("Service Mode");
    bool is_disconnected = IsVPNDisconnected();
    add_item("    Proxy Service", TrayAction::ProxyService, true, proxy_service_, is_disconnected);
    add_item("    System Proxy", TrayAction::SystemProxy, true, system_proxy_, is_disconnected);
    add_item("    VPN (Upcoming)", TrayAction::VPNMode, true, vpn_mode_, false);
    add_separator();

    // Actions section
    add_item("Introduction", TrayAction::OpenIntroduction);
    add_item("Speedtest", TrayAction::OpenSpeedTest);
    add_item("Logs", TrayAction::OpenLogs);
    add_separator();

    // Exit
    add_item("Exit", TrayAction::Exit);

    gtk_widget_show_all(menu);

    return menu;
}

void SystemTray::RebuildMenu()
{
    if (!indicator_)
        return;

    // Create new menu and set it
    GtkWidget *new_menu = CreateMenu();
    app_indicator_set_menu(indicator_, GTK_MENU(new_menu));

    // Destroy old menu if it exists
    if (menu_)
    {
        gtk_widget_destroy(menu_);
    }
    menu_ = new_menu;
}

void SystemTray::Cleanup()
{
    if (menu_)
    {
        gtk_widget_destroy(menu_);
        menu_ = nullptr;
    }

    if (indicator_)
    {
        g_object_unref(indicator_);
        indicator_ = nullptr;
    }

    initialized_ = false;
}

std::string SystemTray::GetIconPath(TrayIconStatus status) const
{
    std::string icon_name;

    switch (status)
    {
    case TrayIconStatus::Connected:
        icon_name = "Icon-Connected.png";
        break;
    case TrayIconStatus::Connecting:
        icon_name = "Icon-Connecting.png";
        break;
    case TrayIconStatus::Failed:
        icon_name = "Icon-Failed.png";
        break;
    case TrayIconStatus::KillSwitch:
        icon_name = "Icon-KillSwitch.png";
        break;
    case TrayIconStatus::NoInternet:
        icon_name = "Icon-NoInternet.png";
        break;
    case TrayIconStatus::Standby:
    default:
        icon_name = "Icon-Standby.png";
        break;
    }

    return icon_dir_ + "/" + icon_name;
}

std::string SystemTray::GetIconName(TrayIconStatus status) const
{
    // Return icon name without extension for AppIndicator
    switch (status)
    {
    case TrayIconStatus::Connected:
        return "Icon-Connected";
    case TrayIconStatus::Connecting:
        return "Icon-Connecting";
    case TrayIconStatus::Failed:
        return "Icon-Failed";
    case TrayIconStatus::KillSwitch:
        return "Icon-KillSwitch";
    case TrayIconStatus::NoInternet:
        return "Icon-NoInternet";
    case TrayIconStatus::Standby:
    default:
        return "Icon-Standby";
    }
}

void SystemTray::OnMenuItemActivated(GtkMenuItem *menu_item, gpointer user_data)
{
    MenuItemData *data = static_cast<MenuItemData *>(user_data);
    if (data && data->tray)
    {
        data->tray->ExecuteAction(data->action);
    }
}

void SystemTray::ExecuteAction(TrayAction action)
{
    // Handle checkbox toggles for service mode
    switch (action)
    {
    case TrayAction::LaunchOnStartup:
        launch_on_startup_ = !launch_on_startup_;
        break;
    case TrayAction::AutoConnect:
        auto_connect_ = !auto_connect_;
        break;
    case TrayAction::SoundEffect:
        sound_effect_ = !sound_effect_;
        break;
    case TrayAction::StartMinimized:
        start_minimized_ = !start_minimized_;
        break;
    case TrayAction::ForceClose:
        force_close_ = !force_close_;
        break;
    case TrayAction::ProxyService:
        proxy_service_ = true;
        system_proxy_ = false;
        vpn_mode_ = false;
        RebuildMenu();
        break;
    case TrayAction::SystemProxy:
        proxy_service_ = false;
        system_proxy_ = true;
        vpn_mode_ = false;
        RebuildMenu();
        break;
    case TrayAction::VPNMode:
        proxy_service_ = false;
        system_proxy_ = false;
        vpn_mode_ = true;
        RebuildMenu();
        break;
    default:
        break;
    }

    if (callback_)
    {
        callback_(action);
    }
}

void SystemTray::UpdateTooltip(const std::string &tooltip)
{
    if (!initialized_ || !indicator_)
    {
        return;
    }
    app_indicator_set_title(indicator_, tooltip.c_str());
}

void SystemTray::UpdateIcon(TrayIconStatus status)
{
    if (!initialized_ || !indicator_)
    {
        return;
    }

    current_icon_status_ = status;
    std::string icon_name = GetIconName(status);

    // Check if icon file exists
    std::string icon_path = GetIconPath(status);
    if (std::filesystem::exists(icon_path))
    {
        app_indicator_set_icon(indicator_, icon_name.c_str());
    }
    else
    {
        // Fallback to system icon
        const char *fallback_icon = "network-vpn";
        switch (status)
        {
        case TrayIconStatus::Connected:
            fallback_icon = "network-vpn";
            break;
        case TrayIconStatus::Connecting:
            fallback_icon = "network-vpn-acquiring";
            break;
        case TrayIconStatus::Failed:
        case TrayIconStatus::NoInternet:
            fallback_icon = "network-offline";
            break;
        default:
            fallback_icon = "network-vpn";
            break;
        }
        app_indicator_set_icon_theme_path(indicator_, nullptr);
        app_indicator_set_icon(indicator_, fallback_icon);
    }
}

std::string SystemTray::ConnectionStatusToString(ConnectionStatus status)
{
    switch (status)
    {
    case ConnectionStatus::Connect:
        return "Connect";
    case ConnectionStatus::Disconnect:
        return "Disconnect";
    case ConnectionStatus::Connecting:
        return "Connecting ...";
    case ConnectionStatus::Disconnecting:
        return "Disconnecting ...";
    case ConnectionStatus::Error:
        return "Error";
    default:
        return "Connect";
    }
}

std::string SystemTray::GetConnectionStatusText() const
{
    return ConnectionStatusToString(connection_status_);
}

void SystemTray::UpdateConnectionStatus(ConnectionStatus status)
{
    connection_status_ = status;
    RebuildMenu();
}

void SystemTray::SetLaunchOnStartup(bool value)
{
    launch_on_startup_ = value;
}

void SystemTray::SetAutoConnect(bool value)
{
    auto_connect_ = value;
}

void SystemTray::SetStartMinimized(bool value)
{
    start_minimized_ = value;
}

void SystemTray::SetForceClose(bool value)
{
    force_close_ = value;
}

void SystemTray::SetSoundEffect(bool value)
{
    sound_effect_ = value;
}

void SystemTray::SetProxyService(bool value)
{
    proxy_service_ = value;
}

void SystemTray::SetSystemProxy(bool value)
{
    system_proxy_ = value;
}

void SystemTray::SetVPNMode(bool value)
{
    vpn_mode_ = value;
}

bool SystemTray::IsVPNDisconnected() const
{
    return connection_status_ == ConnectionStatus::Connect;
}

#pragma GCC diagnostic pop
