[Setup]
AppId=io.github.mingyuchoo.ada-diary
AppName=Ada Diary
AppVersion={#ReleaseVersion}
AppPublisher=Mingyu Choo
DefaultDirName={localappdata}\Programs\Ada Diary
DefaultGroupName=Ada Diary
PrivilegesRequired=lowest
MinVersion=10.0.22000
ArchitecturesAllowed={#WindowsArchitecture}
ArchitecturesInstallIn64BitMode={#WindowsArchitecture}
OutputDir={#ArtifactDirectory}
OutputBaseFilename={#ArtifactName}-setup
Compression=lzma2
SolidCompression=yes
LicenseFile={#SourceDirectory}\LICENSE
UninstallDisplayName=Ada Diary
WizardStyle=modern

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ada Diary"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\diary.ps1"""; WorkingDir: "{app}"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\wsl.exe'));
  if not Result then
    MsgBox('Ada Diary requires WSL and a configured Linux distribution. Run wsl --install, restart Windows if prompted, and complete Linux user setup before installing.', mbError, MB_OK);
end;
