#pragma once

#include <windows.h>

class AdminPrivileges {
 public:
  // Check if the current process is running with administrator privileges
  static bool IsRunningAsAdministrator();

  // Request administrator privileges by relaunching the application with elevation
  // Returns true if elevation was successfully requested, false if user cancelled
  static bool RequestAdministratorPrivileges(HWND window_handle);

 private:
  AdminPrivileges() = delete;
  ~AdminPrivileges() = delete;
};

