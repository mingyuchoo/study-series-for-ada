Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'run.sh'
$applicationArguments = @($args)

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)

    $escapedValue = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escapedValue = [regex]::Replace($escapedValue, '(\\+)$', '$1$1')
    return '"' + $escapedValue + '"'
}

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    $wslCommand = Get-Command wsl.exe -ErrorAction Stop
    $linuxScript = & wsl.exe --exec wslpath -a -u $scriptPath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    if ([string]::IsNullOrWhiteSpace($linuxScript)) {
        throw 'WSL could not resolve the script path.'
    }
    $nativeArguments = @('--exec', 'bash', '-l', $linuxScript.Trim()) + $applicationArguments
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $wslCommand.Source
    $startInfo.UseShellExecute = $false
    $startInfo.Arguments = ($nativeArguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }
    exit $exitCode
} else {
    Get-Command bash -ErrorAction Stop | Out-Null
    & bash $scriptPath @applicationArguments
}

exit $LASTEXITCODE
