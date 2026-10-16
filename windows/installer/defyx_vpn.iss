#define MyAppName "Defyx VPN"
#define MyAppPublisher "UnboundTech UG"
#define MyAppExeName "DefyxVPN.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#ifndef MyAppVersionInfo
  #define MyAppVersionInfo "0.0.0.0"
#endif

#ifndef MyAppSourceDir
  #error MyAppSourceDir must point to the Flutter Windows Release directory.
#endif

#ifndef MyAppOutputDir
  #error MyAppOutputDir must point to the installer output directory.
#endif

#ifndef MyVcRedistPath
  #error MyVcRedistPath must point to the Visual C++ Redistributable installer.
#endif

[Setup]
AppId={{C97AB5D4-D215-4873-AE8D-7D0DAB9AB833}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyAppOutputDir}
OutputBaseFilename=DefyxVPN-Windows-Installer-x64
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersionInfo}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyVcRedistPath}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\{#MyAppName}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent