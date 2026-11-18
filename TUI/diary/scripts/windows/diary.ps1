Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'process.ps1')

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'This launcher requires Windows 11 with WSL.'
    }
    $wsl = (Get-Command wsl.exe -ErrorAction Stop).Source
    $wslArguments = @()
    $distribution = [Environment]::GetEnvironmentVariable('DIARY_WSL_DISTRIBUTION')
    if (-not [string]::IsNullOrWhiteSpace($distribution)) {
        $wslArguments += @('--distribution', $distribution)
    }
    $architecture = Invoke-DiaryProcess $wsl ($wslArguments + @('--exec', 'uname', '-m')) -CaptureOutput
    $expectedArchitecture = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'architecture.txt') -Raw).Trim()
    if ($architecture -ne $expectedArchitecture) {
        throw "This package requires a $expectedArchitecture WSL distribution; found $architecture."
    }
    $binary = Join-Path $PSScriptRoot 'payload/bin/diary'
    $linuxBinary = Invoke-DiaryProcess $wsl ($wslArguments + @('--exec', 'wslpath', '-a', '-u', $binary)) -CaptureOutput
    if ([string]::IsNullOrWhiteSpace($linuxBinary)) {
        throw 'WSL could not resolve the installed application path.'
    }
    Invoke-DiaryProcess $wsl ($wslArguments + @('--exec', $linuxBinary) + @($args))
} catch {
    Write-Error -ErrorRecord $_ -ErrorAction Continue
    exit 1
}
