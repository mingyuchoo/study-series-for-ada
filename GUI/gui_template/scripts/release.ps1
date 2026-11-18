#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Run this script on Windows.'
}

function Invoke-Native {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Crate {
    param(
        [string]$Directory,
        [scriptblock]$Action
    )

    Push-Location -LiteralPath $Directory
    try {
        & $Action
    }
    finally {
        Pop-Location
    }
}

$alr = (Get-Command alr -CommandType Application).Source
$formatter = (Get-Command gnatformat -CommandType Application).Source
$compiler = Get-Command ISCC.exe -CommandType Application -ErrorAction SilentlyContinue
if ($compiler) {
    $iscc = $compiler.Source
}
else {
    $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path -LiteralPath $iscc -PathType Leaf)) {
        throw 'Install Inno Setup 6.3 or later and add ISCC.exe to PATH.'
    }
}

$app = 'apps/counter_windows'
$packages = @('packages/counter_domain', 'packages/counter_application')
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "$app/alire.toml")
if ($manifest -notmatch '(?m)^version = "([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)"\r?$') {
    throw 'Invalid application version in alire.toml.'
}
$version = $Matches[1]

$dist = Join-Path $PSScriptRoot 'dist'
$null = New-Item -ItemType Directory -Path $dist -Force
$work = Join-Path $dist ('.release.' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
Push-Location -LiteralPath $work
try {
    foreach ($crate in ($packages + $app)) {
        $source = Join-Path $PSScriptRoot $crate
        $target = Join-Path $work $crate
        $null = New-Item -ItemType Directory -Path $target
        Copy-Item -LiteralPath (Join-Path $source 'src') -Destination $target -Recurse
        Copy-Item -LiteralPath (Join-Path $source 'alire.toml') -Destination $target
        Get-ChildItem -LiteralPath $source -Filter '*.gpr' -File |
            Copy-Item -Destination $target
    }
    foreach ($package in $packages) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "$package/tests") -Destination $package -Recurse
    }

    Write-Host 'Formatting Ada sources'
    $sources = Get-ChildItem -Path 'apps', 'packages' -Recurse -File -Include '*.adb', '*.ads'
    Invoke-Native $formatter @($sources.FullName)

    Write-Host 'Linting Ada sources'
    foreach ($package in $packages) {
        Invoke-Crate $package {
            Invoke-Native $alr @('-n', 'exec', '--', 'gprbuild', '-P', 'counter_tests.gpr',
                '-c', '-f', '-cargs:Ada', '-gnatwa', '-gnatwe')
        }
    }
    Invoke-Crate $app {
        $units = Get-ChildItem -LiteralPath 'src' -Recurse -File -Filter '*.adb'
        Invoke-Native $alr (@('-n', 'exec', '--', 'gprbuild', '-P', 'counter_windows.gpr',
            '-c', '-f', '-u') + $units.Name + @('-cargs:Ada', '-gnatwa', '-gnatwe'))
    }

    Write-Host 'Building the release executable'
    Invoke-Crate $app {
        Invoke-Native $alr @('-n', 'build', '--release', '--', '-largs', '-static')
    }
    $targetMachine = Invoke-Crate $app {
        Invoke-Native $alr @('-n', 'exec', '--', 'gcc', '-dumpmachine')
    }
    switch -Regex ($targetMachine) {
        '^x86_64-' { $architecture = 'x64'; $allowedArchitecture = 'x64compatible' }
        '^i[3-6]86-' { $architecture = 'x86'; $allowedArchitecture = 'x86compatible' }
        '^aarch64-' { $architecture = 'arm64'; $allowedArchitecture = 'arm64' }
        default { throw "Unsupported compiler target $targetMachine." }
    }

    Write-Host 'Running tests'
    foreach ($package in $packages) {
        Invoke-Crate $package {
            Invoke-Native $alr @('-n', 'exec', '--', 'gprbuild', '-P', 'counter_tests.gpr')
            Invoke-Native $alr @('-n', 'exec', '--', '.\bin\test_counter.exe')
        }
    }

    Write-Host 'Bundling and building the installer'
    $null = New-Item -ItemType Directory -Path 'bundle'
    Copy-Item -LiteralPath "$app/bin/counter_windows.exe", (Join-Path $PSScriptRoot 'LICENSE') -Destination 'bundle'
    $installer = "counter-windows-$version-$architecture-setup"
    @"
[Setup]
AppId=com.mingyuchoo.counter
AppName=Counter
AppVersion=$version
DefaultDirName={localappdata}\Programs\Counter
PrivilegesRequired=lowest
MinVersion=10.0.22000
ArchitecturesAllowed=$allowedArchitecture
OutputDir=.
OutputBaseFilename=$installer

[Files]
Source: "bundle\counter_windows.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "bundle\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Counter"; Filename: "{app}\counter_windows.exe"
"@ | Set-Content -LiteralPath 'counter.iss' -Encoding Ascii
    Invoke-Native $iscc @('counter.iss')
    $artifact = Join-Path $dist "$installer.exe"
    Move-Item -LiteralPath "$installer.exe" -Destination $artifact -Force
    Write-Host "Installer: $artifact"
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $work -Recurse -Force
}
