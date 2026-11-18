Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectRoot 'scripts/windows/process.ps1')

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts') -Recurse -Filter '*.ps1') {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        throw ($parseErrors | Out-String)
    }
}

$cases = @(
    @('', '""'),
    @('path with spaces', '"path with spaces"'),
    @('quoted"value', '"quoted\"value"'),
    @('C:\path\', '"C:\path\\"'),
    @('$() & value', '"$() & value"')
)
foreach ($case in $cases) {
    $actual = ConvertTo-DiaryNativeArgument $case[0]
    if ($actual -cne $case[1]) {
        throw "Native argument was escaped incorrectly: $actual"
    }
}

$shell = (Get-Process -Id $PID).Path
$captured = Invoke-DiaryProcess $shell @('-NoLogo', '-NoProfile', '-Command', '[Console]::Write("path with spaces and quotes")') -CaptureOutput
if ($captured -cne 'path with spaces and quotes') {
    throw "Native process output was not preserved: $captured"
}
$failed = $false
try {
    Invoke-DiaryProcess $shell @('-NoLogo', '-NoProfile', '-Command', 'exit 42')
} catch {
    $failed = $_.Exception.Message -like '*exit code 42*'
}
if (-not $failed) {
    throw 'Native process failure did not propagate.'
}
$helpOutput = Invoke-DiaryProcess $shell @('-NoLogo', '-NoProfile', '-File', (Join-Path $projectRoot 'scripts/release.ps1'), '-Help') -CaptureOutput
if ($helpOutput -notlike '*InnoSetupCompiler*') {
    throw 'Release help failed.'
}
Write-Output 'PASS PowerShell syntax, native argument escaping, process output, failure propagation, and help'
