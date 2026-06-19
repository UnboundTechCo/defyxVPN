#include "my_application.h"

#include <glib.h>

// Custom GLib log writer to keep the terminal clean for end users.
// Native libraries (GTK, appindicator, ibus, xdg-portal, the Flutter GLib
// embedder, etc.) emit a lot of WARNING/CRITICAL noise that is harmless and
// only visible when launching from a terminal. We suppress that noise here.
// Genuine fatal errors are still printed so real crashes are not hidden.
static GLogWriterOutput DefyxLogWriter(GLogLevelFlags log_level,
                                       const GLogField *fields,
                                       gsize n_fields,
                                       gpointer user_data) {
  if (log_level & (G_LOG_LEVEL_ERROR | G_LOG_FLAG_FATAL)) {
    return g_log_writer_standard_streams(log_level, fields, n_fields,
                                         user_data);
  }
  return G_LOG_WRITER_HANDLED;
}

int main(int argc, char** argv) {
  g_log_set_writer_func(DefyxLogWriter, nullptr, nullptr);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
