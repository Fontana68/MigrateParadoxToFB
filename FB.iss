; ------------------------------------------------------------
;  MigrateParadoxToFB – Installer Inno Setup
;  Autore: Leonardo (Parma)
; ------------------------------------------------------------

#define MyAppName "Migrate Paradox to Firebird"
#define MyAppExeName "MigrateParadoxToFB.exe"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Leonardo"
#define MyAppURL "https://example.com"

[Setup]
AppId={{767CF0EF-7021-432A-96B6-E857CFC5D099}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.\Output
OutputBaseFilename=MigrateParadoxToFB_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Files]
; --- Applicazione principale ---
Source: "..\bin\Win32\Release\MigrateParadoxToFB.exe"; DestDir: "{app}"; Flags: ignoreversion

; --- Firebird Embedded ---
Source: "FB\fbclient.dll"; DestDir: "{app}\FB"; Flags: ignoreversion
Source: "FB\icudt*.dll"; DestDir: "{app}\FB"; Flags: ignoreversion
Source: "FB\firebird.conf"; DestDir: "{app}\FB"; Flags: ignoreversion

; --- Cartelle Paradox e Report ---
Source: "Paradox\*"; DestDir: "{app}\Paradox"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Report\*"; DestDir: "{app}\Report"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{app}\Paradox"
Name: "{app}\FB"
Name: "{app}\Report"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crea icona sul desktop"; GroupDescription: "Opzioni aggiuntive"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Avvia applicazione"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Report"
Type: filesandordirs; Name: "{app}\Paradox"
Type: filesandordirs; Name: "{app}\FB"
