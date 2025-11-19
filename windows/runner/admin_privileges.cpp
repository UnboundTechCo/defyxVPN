#include "admin_privileges.h"

#include <string>
#include <shellapi.h>
#pragma comment(lib, "shell32.lib")

bool AdminPrivileges::IsRunningAsAdministrator() {
  BOOL isAdmin = FALSE;
  PSID administratorsGroup = NULL;
  SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;

  if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                &administratorsGroup)) {
    if (!CheckTokenMembership(NULL, administratorsGroup, &isAdmin)) {
      isAdmin = FALSE;
    }
    FreeSid(administratorsGroup);
  }

  return isAdmin == TRUE;
}

bool AdminPrivileges::RequestAdministratorPrivileges(HWND window_handle) {
  wchar_t szPath[MAX_PATH];
  if (GetModuleFileNameW(NULL, szPath, ARRAYSIZE(szPath)) == 0) {
    return false;
  }

  LPWSTR* szArglist;
  int nArgs;
  szArglist = CommandLineToArgvW(GetCommandLineW(), &nArgs);

  std::wstring args;
  for (int i = 1; i < nArgs; i++) {
    if (i > 1) args += L" ";
    args += szArglist[i];
  }
  LocalFree(szArglist);

  SHELLEXECUTEINFOW sei = { sizeof(sei) };
  sei.lpVerb = L"runas";
  sei.lpFile = szPath;
  sei.lpParameters = args.c_str();
  sei.hwnd = window_handle;
  sei.nShow = SW_NORMAL;

  if (!ShellExecuteExW(&sei)) {
    DWORD dwError = GetLastError();
    if (dwError == ERROR_CANCELLED) {
      return false;
    }
  }

  return true;
}

