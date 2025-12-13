#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <thread>
#include <chrono>

#include "flutter/generated_plugin_registrant.h"
#include "system_tray.h"
#include "settings_manager.h"
#include "vpn_channel_handler.h"
#include "defyx_core.h"

// Forward declaration for our custom plugin
void RegisterDefyxLinuxPlugin(FlPluginRegistrar *registrar);

// Global instances
static SystemTray *g_system_tray = nullptr;
static VPNChannelHandler *g_vpn_channel_handler = nullptr;
static SettingsManager *g_settings_manager = nullptr;
static GtkWindow *g_main_window = nullptr;
static FlView *g_flutter_view = nullptr;

struct _MyApplication
{
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
  gboolean start_minimized;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Handle tray actions
static void HandleTrayAction(SystemTray::TrayAction action)
{
  if (!g_main_window)
    return;

  switch (action)
  {
  case SystemTray::TrayAction::ShowWindow:
    gtk_window_present(g_main_window);
    break;

  case SystemTray::TrayAction::ToggleWindow:
    if (gtk_widget_get_visible(GTK_WIDGET(g_main_window)))
    {
      gtk_widget_hide(GTK_WIDGET(g_main_window));
    }
    else
    {
      gtk_window_present(g_main_window);
    }
    break;

  case SystemTray::TrayAction::LaunchOnStartup:
    if (g_settings_manager)
    {
      bool is_enabled = g_settings_manager->IsLaunchOnStartupEnabled();
      g_settings_manager->SetLaunchOnStartup(!is_enabled);
      if (g_system_tray)
      {
        g_system_tray->SetLaunchOnStartup(!is_enabled);
      }
    }
    break;

  case SystemTray::TrayAction::AutoConnect:
    if (g_settings_manager && g_system_tray)
    {
      g_settings_manager->SetAutoConnect(g_system_tray->GetAutoConnect());

      if (g_flutter_view)
      {
        FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
            fl_view_get_engine(g_flutter_view));
        g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
        FlMethodChannel *channel = fl_method_channel_new(
            messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "value",
                                 fl_value_new_bool(g_system_tray->GetAutoConnect()));
        fl_method_channel_invoke_method(channel, "setAutoConnect", args,
                                        nullptr, nullptr, nullptr);
        g_object_unref(channel);
      }
    }
    break;

  case SystemTray::TrayAction::StartMinimized:
    if (g_settings_manager && g_system_tray)
    {
      g_settings_manager->SetStartMinimized(g_system_tray->GetStartMinimized());

      if (g_flutter_view)
      {
        FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
            fl_view_get_engine(g_flutter_view));
        g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
        FlMethodChannel *channel = fl_method_channel_new(
            messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "value",
                                 fl_value_new_bool(g_system_tray->GetStartMinimized()));
        fl_method_channel_invoke_method(channel, "setStartMinimized", args,
                                        nullptr, nullptr, nullptr);
        g_object_unref(channel);
      }
    }
    break;

  case SystemTray::TrayAction::ForceClose:
    if (g_settings_manager && g_system_tray)
    {
      g_settings_manager->SetForceClose(g_system_tray->GetForceClose());

      if (g_flutter_view)
      {
        FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
            fl_view_get_engine(g_flutter_view));
        g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
        FlMethodChannel *channel = fl_method_channel_new(
            messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "value",
                                 fl_value_new_bool(g_system_tray->GetForceClose()));
        fl_method_channel_invoke_method(channel, "setForceClose", args,
                                        nullptr, nullptr, nullptr);
        g_object_unref(channel);
      }
    }
    break;

  case SystemTray::TrayAction::SoundEffect:
    if (g_settings_manager && g_system_tray)
    {
      g_settings_manager->SetSoundEffect(g_system_tray->GetSoundEffect());

      if (g_flutter_view)
      {
        FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
            fl_view_get_engine(g_flutter_view));
        g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
        FlMethodChannel *channel = fl_method_channel_new(
            messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "value",
                                 fl_value_new_bool(g_system_tray->GetSoundEffect()));
        fl_method_channel_invoke_method(channel, "setSoundEffect", args,
                                        nullptr, nullptr, nullptr);
        g_object_unref(channel);
      }
    }
    break;

  case SystemTray::TrayAction::ProxyService:
    if (g_settings_manager)
    {
      g_settings_manager->SetServiceMode(0);
    }
    break;

  case SystemTray::TrayAction::SystemProxy:
    if (g_settings_manager)
    {
      g_settings_manager->SetServiceMode(1);
    }
    break;

  case SystemTray::TrayAction::VPNMode:
    if (g_settings_manager)
    {
      g_settings_manager->SetServiceMode(2);
    }
    break;

  case SystemTray::TrayAction::OpenIntroduction:
    gtk_window_present(g_main_window);
    if (g_flutter_view)
    {
      FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
          fl_view_get_engine(g_flutter_view));
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      FlMethodChannel *channel = fl_method_channel_new(
          messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));
      fl_method_channel_invoke_method(channel, "openIntroduction", nullptr,
                                      nullptr, nullptr, nullptr);
      g_object_unref(channel);
    }
    break;

  case SystemTray::TrayAction::OpenSpeedTest:
    gtk_window_present(g_main_window);
    if (g_flutter_view)
    {
      FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
          fl_view_get_engine(g_flutter_view));
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      FlMethodChannel *channel = fl_method_channel_new(
          messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));
      fl_method_channel_invoke_method(channel, "openSpeedTest", nullptr,
                                      nullptr, nullptr, nullptr);
      g_object_unref(channel);
    }
    break;

  case SystemTray::TrayAction::OpenLogs:
    gtk_window_present(g_main_window);
    if (g_flutter_view)
    {
      FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
          fl_view_get_engine(g_flutter_view));
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      FlMethodChannel *channel = fl_method_channel_new(
          messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));
      fl_method_channel_invoke_method(channel, "openLogs", nullptr,
                                      nullptr, nullptr, nullptr);
      g_object_unref(channel);
    }
    break;

  case SystemTray::TrayAction::OpenPreferences:
    gtk_window_present(g_main_window);
    if (g_flutter_view)
    {
      FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
          fl_view_get_engine(g_flutter_view));
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      FlMethodChannel *channel = fl_method_channel_new(
          messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));
      fl_method_channel_invoke_method(channel, "openPreferences", nullptr,
                                      nullptr, nullptr, nullptr);
      g_object_unref(channel);
    }
    break;

  case SystemTray::TrayAction::ConnectionStatusClick:
    gtk_window_present(g_main_window);
    if (g_flutter_view && g_system_tray)
    {
      FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(
          fl_view_get_engine(g_flutter_view));
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      FlMethodChannel *channel = fl_method_channel_new(
          messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

      g_autoptr(FlValue) args = fl_value_new_map();
      fl_value_set_string_take(args, "status",
                               fl_value_new_string(g_system_tray->GetConnectionStatusText().c_str()));
      fl_method_channel_invoke_method(channel, "handleConnectionStatusClick", args,
                                      nullptr, nullptr, nullptr);
      g_object_unref(channel);
    }
    break;

  case SystemTray::TrayAction::Exit:
    if (g_main_window)
    {
      gtk_widget_destroy(GTK_WIDGET(g_main_window));
    }
    break;
  }
}

// Window delete event handler
static gboolean on_window_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
  if (g_system_tray && !g_system_tray->GetForceClose())
  {
    gtk_widget_hide(widget);
    return TRUE; // Prevent destruction
  }
  return FALSE; // Allow destruction
}

// Implements GApplication::activate.
static void my_application_activate(GApplication *application)
{
  MyApplication *self = MY_APPLICATION(application);
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  g_main_window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen *screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen))
  {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0)
    {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar)
  {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "DefyxVPN");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  }
  else
  {
    gtk_window_set_title(window, "DefyxVPN");
  }

  // Set window size to match Windows (400x700)
  gtk_window_set_default_size(window, 400, 700);

  // Disable window resizing (like Windows: ~WS_THICKFRAME)
  gtk_window_set_resizable(window, FALSE);

  // Disable maximize button (like Windows: ~WS_MAXIMIZEBOX)
  GdkGeometry geometry;
  geometry.max_width = 400;
  geometry.max_height = 700;
  geometry.min_width = 400;
  geometry.min_height = 700;
  gtk_window_set_geometry_hints(window, nullptr, &geometry,
                                static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));

  // Initialize settings manager
  g_settings_manager = new SettingsManager();

  // Check if window should start minimized
  bool should_show_window = !g_settings_manager->GetStartMinimized() && !self->start_minimized;

  // Connect delete event handler for minimize to tray
  g_signal_connect(G_OBJECT(window), "delete-event",
                   G_CALLBACK(on_window_delete_event), nullptr);

  if (should_show_window)
  {
    gtk_widget_show(GTK_WIDGET(window));
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView *view = fl_view_new(project);
  g_flutter_view = view;
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Register custom DefyX VPN plugin
  g_autoptr(FlPluginRegistrar) defyx_registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(view), "DefyxLinuxPlugin");
  RegisterDefyxLinuxPlugin(defyx_registrar);

  // Load the DXcore library
  defyx_core::LoadCoreDll("");

  // Get messenger for VPN channel handler
  FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));

  // Initialize system tray
  g_system_tray = new SystemTray();
  g_system_tray->Initialize(window, HandleTrayAction);
  g_system_tray->UpdateIcon(SystemTray::TrayIconStatus::Standby);
  g_system_tray->UpdateTooltip("DefyxVPN - Ready");

  // Initialize VPN channel handler with system tray
  g_vpn_channel_handler = new VPNChannelHandler(messenger, window, g_system_tray);
  g_vpn_channel_handler->SetupChannels();

  // Load preferences from settings
  g_system_tray->SetLaunchOnStartup(g_settings_manager->IsLaunchOnStartupEnabled());
  g_system_tray->SetAutoConnect(g_settings_manager->GetAutoConnect());
  g_system_tray->SetStartMinimized(g_settings_manager->GetStartMinimized());
  g_system_tray->SetForceClose(g_settings_manager->GetForceClose());
  g_system_tray->SetSoundEffect(g_settings_manager->GetSoundEffect());

  int service_mode = g_settings_manager->GetServiceMode();
  if (service_mode == 0)
  {
    g_system_tray->SetProxyService(true);
    g_system_tray->SetSystemProxy(false);
    g_system_tray->SetVPNMode(false);
  }
  else if (service_mode == 1)
  {
    g_system_tray->SetProxyService(false);
    g_system_tray->SetSystemProxy(true);
    g_system_tray->SetVPNMode(false);
  }
  else if (service_mode == 2)
  {
    g_system_tray->SetProxyService(false);
    g_system_tray->SetSystemProxy(false);
    g_system_tray->SetVPNMode(true);
  }

  // Rebuild the menu to reflect loaded settings
  g_system_tray->RebuildMenu();

  // Send initial sound effect setting to Flutter
  {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    FlMethodChannel *channel = fl_method_channel_new(
        messenger, "com.defyx.vpn", FL_METHOD_CODEC(codec));

    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "value",
                             fl_value_new_bool(g_settings_manager->GetSoundEffect()));
    fl_method_channel_invoke_method(channel, "setSoundEffect", args,
                                    nullptr, nullptr, nullptr);
    g_object_unref(channel);
  }

  // Handle auto-connect
  if (g_system_tray->GetAutoConnect())
  {
    std::thread([messenger]()
                {
      std::this_thread::sleep_for(std::chrono::milliseconds(1000));
      
      g_idle_add([](gpointer data) -> gboolean {
        FlBinaryMessenger* msg = static_cast<FlBinaryMessenger*>(data);
        g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
        FlMethodChannel* channel = fl_method_channel_new(
            msg, "com.defyx.vpn", FL_METHOD_CODEC(codec));
        fl_method_channel_invoke_method(channel, "triggerAutoConnect", nullptr,
                                        nullptr, nullptr, nullptr);
        g_object_unref(channel);
        return FALSE;
      }, messenger); })
        .detach();
  }

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication *application, gchar ***arguments, int *exit_status)
{
  MyApplication *self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  // Check for --startup argument
  self->start_minimized = FALSE;
  for (gchar **arg = self->dart_entrypoint_arguments; arg && *arg; ++arg)
  {
    if (g_strcmp0(*arg, "--startup") == 0)
    {
      self->start_minimized = TRUE;
      break;
    }
  }

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error))
  {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication *application)
{
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication *application)
{
  // MyApplication* self = MY_APPLICATION(object);

  // Cleanup global instances
  if (g_vpn_channel_handler)
  {
    delete g_vpn_channel_handler;
    g_vpn_channel_handler = nullptr;
  }

  if (g_system_tray)
  {
    g_system_tray->Cleanup();
    delete g_system_tray;
    g_system_tray = nullptr;
  }

  if (g_settings_manager)
  {
    delete g_settings_manager;
    g_settings_manager = nullptr;
  }

  // Unload the DXcore library
  defyx_core::UnloadCoreDll();

  g_main_window = nullptr;
  g_flutter_view = nullptr;

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject *object)
{
  MyApplication *self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass *klass)
{
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {}

MyApplication *my_application_new()
{
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
