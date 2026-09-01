; MKVoodoo Installer Script
#define MyAppName "MKVoodoo"
#define MyAppVersion "1.2.1"
#define MyAppPublisher "Synontech"
#define MyAppExeName "mkvoodoo_ui.exe"
#define BackendExeName "mkvoodoo_backend.exe"

[Setup]
; Unique AppId (randomly generated for SynonTech)
AppId={{C6E97E22-9F12-4C3D-B900-FF39FF140123}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=MKVoodoo_v1.2.1_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; --- Professional Additions ---
LicenseFile=LICENSE.txt
InfoBeforeFile=INSTALL_INFO.txt
; ------------------------------

; Icon for the installer itself (using your app icon)
SetupIconFile=frontend\windows\runner\resources\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 1. The Flutter UI
Source: "frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 2. The Nuitka Backend (Compiled folder)
Source: "main.dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 3. The FFmpeg Binaries (Backend expects these in backend\bin relative to the exe)
Source: "backend\bin\*"; DestDir: "{app}\backend\bin"; Excludes: "deno.exe"; Flags: ignoreversion recursesubdirs createallsubdirs

; 4. Deno is required by current yt-dlp YouTube challenge solving. Keeping it
; explicit makes the installer build fail instead of silently shipping a dud.
Source: "backend\bin\deno.exe"; DestDir: "{app}\backend\bin"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
