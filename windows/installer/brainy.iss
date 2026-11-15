; Brainy — Windows installer (Inno Setup 6).
; Build the app first:  flutter build windows --release --dart-define=API_URL=... --dart-define=WEB_APP_URL=...
; Then from brainy/:    ISCC windows\installer\brainy.iss
; Output: build\installer\Brainy-<version>-windows-setup.exe

#define AppName "Brainy"
#define AppVersion "1.0.0"
#define AppExe "brainy.exe"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"
[Setup]
; Keep this AppId forever: Windows uses it to recognise updates of the same app.
AppId={{54D6303E-A5A5-48E7-94DF-71F30724876C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Brainy
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Installs for the current user without administrator rights; the user may choose all users instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\build\installer
OutputBaseFilename=Brainy-{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; The Release folder must also hold the 64-bit Microsoft C++ runtime (msvcp140.dll, vcruntime140.dll,
; vcruntime140_1.dll copied from C:\Windows\System32 by a 64-bit shell), so the app starts on PCs
; without it. ISCC is a 32-bit program and would read the 32-bit copies from System32.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
