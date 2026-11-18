Set-StrictMode -Version Latest

function ConvertTo-TuiTemplateNativeArgument {
    param([AllowEmptyString()][string]$Value)

    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-TuiTemplateProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [switch]$CaptureOutput
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $CaptureOutput.IsPresent
    if ($CaptureOutput) {
        $startInfo.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    }
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $startInfo.Arguments = ($ArgumentList | ForEach-Object { ConvertTo-TuiTemplateNativeArgument $_ }) -join ' '
    } else {
        foreach ($argument in $ArgumentList) {
            $startInfo.ArgumentList.Add($argument)
        }
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        if ($CaptureOutput) {
            $output = $process.StandardOutput.ReadToEnd()
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "$FilePath failed with exit code $($process.ExitCode)."
        }
        if ($CaptureOutput) {
            return $output.Trim()
        }
    } finally {
        $process.Dispose()
    }
}
