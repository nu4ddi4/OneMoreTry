; Build with Inno Setup 6: ISCC /DAppVersion=0.2.0 installer\OneMoreTry.iss
#ifndef AppVersion
  #error AppVersion must match project.godot
#endif
[Setup]
AppId={{8B5C1547-21FA-47B4-B183-B0CF8AA2F502}
AppName=One More Try!
AppVersion={#AppVersion}
AppPublisher=One More Try!
AppPublisherURL=https://github.com/nu4ddi4/side-scroller-game
AppUpdatesURL=https://github.com/nu4ddi4/side-scroller-game/releases/latest
DefaultDirName={localappdata}\Programs\OneMoreTry
DefaultGroupName=One More Try!
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\installer
OutputBaseFilename=OneMoreTry-v{#AppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\OneMoreTry.exe
CloseApplications=yes
CloseApplicationsFilter=OneMoreTry.exe
RestartApplications=no
SetupLogging=yes
VersionInfoVersion={#AppVersion}.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\OneMoreTry.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\One More Try!"; Filename: "{app}\OneMoreTry.exe"
Name: "{autodesktop}\One More Try!"; Filename: "{app}\OneMoreTry.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\OneMoreTry.exe"; Description: "{cm:LaunchProgram,One More Try!}"; Flags: nowait postinstall skipifsilent

; Deliberately no user-data deletion: records and settings survive upgrades/uninstall.
