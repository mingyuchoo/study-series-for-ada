[Setup]
AppId=io.github.mingyuchoo.ada-tui-template
AppName=Ada TUI Template
AppVersion={#ReleaseVersion}
AppPublisher=Mingyu Choo
DefaultDirName={localappdata}\Programs\Ada TUI Template
DefaultGroupName=Ada TUI Template
PrivilegesRequired=lowest
MinVersion=10.0.22000
ArchitecturesAllowed={#WindowsArchitecture}
ArchitecturesInstallIn64BitMode={#WindowsArchitecture}
OutputDir={#ArtifactDirectory}
OutputBaseFilename={#ArtifactName}-setup
Compression=lzma2
SolidCompression=yes
LicenseFile={#SourceDirectory}\LICENSE
UninstallDisplayName=Ada TUI Template
WizardStyle=modern

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ada TUI Template"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tui_template.ps1"""; WorkingDir: "{app}"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\wsl.exe'));
  if not Result then
    MsgBox('Ada TUI Template requires WSL and a configured Linux distribution. Run wsl --install, restart Windows if prompted, and complete Linux user setup before installing.', mbError, MB_OK);
end;
