param(
    [string]$Version = '',
    [string]$OutputDirectory = '',
    [string]$Distribution = '',
    [string]$InnoSetupCompiler = '',
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./scripts/release.ps1 [-Version VERSION] [-OutputDirectory DIRECTORY] [-Distribution WSL_NAME] [-InnoSetupCompiler ISCC_PATH]'
    Write-Output 'Runs formatting, linting, release build, and all tests in WSL, then creates a Windows 11 installer, portable ZIP, source archive, and SHA-256 manifest.'
    exit 0
}

. (Join-Path $PSScriptRoot 'windows/process.ps1')
$workspace = $null

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or [Environment]::OSVersion.Version.Build -lt 22000) {
        throw 'release.ps1 requires Windows 11 with a configured WSL distribution. Use release.sh on Linux or macOS.'
    }
    $projectRoot = Split-Path -Parent $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($Version)) {
        $manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'alire.toml') -Raw
        $Version = [regex]::Match($manifest, '(?m)^version\s*=\s*"([^"]+)"').Groups[1].Value
    }
    if ($Version -notmatch '\A[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?\z') {
        throw 'Version must be MAJOR.MINOR.PATCH with an optional prerelease suffix.'
    }
    $wsl = (Get-Command wsl.exe -ErrorAction Stop).Source
    Get-Command tar.exe -ErrorAction Stop | Out-Null
    if ([string]::IsNullOrWhiteSpace($InnoSetupCompiler)) {
        $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
        if ($null -ne $compilerCommand) {
            $InnoSetupCompiler = $compilerCommand.Source
        } else {
            $candidates = @(
                (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'),
                (Join-Path $env:ProgramFiles 'Inno Setup 6/ISCC.exe'),
                (Join-Path $env:LOCALAPPDATA 'Programs/Inno Setup 6/ISCC.exe')
            )
            foreach ($candidate in $candidates) {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $InnoSetupCompiler = $candidate
                    break
                }
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($InnoSetupCompiler) -or -not (Test-Path -LiteralPath $InnoSetupCompiler -PathType Leaf)) {
        throw 'Inno Setup 6.3 or newer is required. Install it or pass -InnoSetupCompiler with the ISCC.exe path.'
    }
    $InnoSetupCompiler = (Resolve-Path -LiteralPath $InnoSetupCompiler).Path
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $projectRoot 'dist'
    }
    $OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
    $wslArguments = @()
    if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
        $wslArguments += @('--distribution', $Distribution)
    }
    $hostArchitecture = Invoke-TuiTemplateProcess $wsl ($wslArguments + @('--exec', 'uname', '-m')) -CaptureOutput
    switch ($hostArchitecture) {
        'x86_64' { $architecture = 'amd64'; $windowsArchitecture = 'x64os' }
        'aarch64' { $architecture = 'arm64'; $windowsArchitecture = 'arm64' }
        default { throw "Unsupported WSL architecture: $hostArchitecture" }
    }
    $workspace = Join-Path ([IO.Path]::GetTempPath()) ('tui_template-release-' + [Guid]::NewGuid().ToString('N'))
    $linuxOutput = Join-Path $workspace 'linux'
    $artifacts = Join-Path $workspace 'artifacts'
    $payloadRoot = Join-Path $workspace 'portable'
    New-Item -ItemType Directory -Path $linuxOutput, $artifacts, $payloadRoot -Force | Out-Null
    $linuxScript = Invoke-TuiTemplateProcess $wsl ($wslArguments + @('--exec', 'wslpath', '-a', '-u', (Join-Path $PSScriptRoot 'release.sh'))) -CaptureOutput
    $linuxOutputPath = Invoke-TuiTemplateProcess $wsl ($wslArguments + @('--exec', 'wslpath', '-a', '-u', $linuxOutput)) -CaptureOutput
    if ([string]::IsNullOrWhiteSpace($linuxScript) -or [string]::IsNullOrWhiteSpace($linuxOutputPath)) {
        throw 'WSL could not resolve release paths. Keep the checkout and output on a drive accessible to WSL.'
    }
    Invoke-TuiTemplateProcess $wsl ($wslArguments + @('--exec', 'bash', '-l', $linuxScript, '--version', $Version, '--output', $linuxOutputPath, '--bundle-only'))
    $linuxArchive = Join-Path $linuxOutput "tui_template-$Version-linux-$architecture.tar.gz"
    $payload = Join-Path $payloadRoot 'payload'
    New-Item -ItemType Directory -Path $payload | Out-Null
    Invoke-TuiTemplateProcess 'tar.exe' @('-xzf', $linuxArchive, '--strip-components', '1', '-C', $payload)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows/tui_template.ps1'), (Join-Path $PSScriptRoot 'windows/process.ps1'), (Join-Path $projectRoot 'LICENSE') -Destination $payloadRoot
    Set-Content -LiteralPath (Join-Path $payloadRoot 'architecture.txt') -Value $hostArchitecture -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $payloadRoot 'tui_template.cmd') -Encoding ASCII -Value @(
        '@echo off',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tui_template.ps1" %*'
    )
    $artifactName = "tui_template-$Version-windows-$architecture"
    Compress-Archive -Path (Join-Path $payloadRoot '*') -DestinationPath (Join-Path $artifacts "$artifactName.zip")
    Copy-Item -LiteralPath (Join-Path $linuxOutput "tui_template-$Version-linux-$architecture-source.tar.gz") -Destination (Join-Path $artifacts "$artifactName-source.tar.gz")
    Invoke-TuiTemplateProcess $InnoSetupCompiler @(
        "/DReleaseVersion=$Version",
        "/DWindowsArchitecture=$windowsArchitecture",
        "/DArtifactDirectory=$artifacts",
        "/DArtifactName=$artifactName",
        "/DSourceDirectory=$payloadRoot",
        (Join-Path $PSScriptRoot 'windows/tui_template.iss')
    )
    $checksums = @(Get-ChildItem -LiteralPath $artifacts -File | Sort-Object Name | ForEach-Object {
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($_.Name)"
    })
    [IO.File]::WriteAllText((Join-Path $artifacts "$artifactName-SHA256SUMS"), ($checksums -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Get-ChildItem -LiteralPath $artifacts -File | Copy-Item -Destination $OutputDirectory
    Write-Output "Release artifacts: $OutputDirectory"
} catch {
    Write-Error -ErrorRecord $_ -ErrorAction Continue
    exit 1
} finally {
    if ($null -ne $workspace -and (Test-Path -LiteralPath $workspace)) {
        Remove-Item -LiteralPath $workspace -Recurse -Force
    }
}
