#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  const bool tunnel_mode =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--tun") != command_line_arguments.end();

  HANDLE hMutex = CreateMutexW(nullptr, TRUE,
                               tunnel_mode ? L"DefyxVPN_TunnelInstance"
                                           : L"DefyxVPN_SingleInstance");
  if (GetLastError() == ERROR_ALREADY_EXISTS)
  {
    if (!tunnel_mode)
    {
      HWND hwnd = FindWindowW(nullptr, L"DefyxVPN");
      if (hwnd)
      {
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
      }
    }
    return 0;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, tunnel_mode);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(400, 700);
  if (!window.Create(tunnel_mode ? L"DefyxVPN Tunnel" : L"DefyxVPN", origin,
                     size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ReleaseMutex(hMutex);
  CloseHandle(hMutex);
  return EXIT_SUCCESS;
}
