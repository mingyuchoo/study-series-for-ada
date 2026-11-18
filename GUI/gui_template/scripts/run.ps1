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
$root = Split-Path -Parent $PSScriptRoot
$app = 'apps/counter_windows'
$packages = @('packages/counter_domain', 'packages/counter_application')

Invoke-Crate $root {
    Write-Host 'Formatting Ada sources'
    $sourceDirectories = @(
        'apps/counter_tk/src',
        'apps/counter_windows/src',
        'packages/counter_domain/src',
        'packages/counter_domain/tests',
        'packages/counter_application/src',
        'packages/counter_application/tests'
    )
    $sources = Get-ChildItem -LiteralPath $sourceDirectories -Recurse -File |
        Where-Object { $_.Extension -in '.adb', '.ads' }
    Invoke-Native $formatter (@('--no-project') + $sources.FullName)

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

    Write-Host 'Building the application'
    Invoke-Crate $app {
        Invoke-Native $alr @('-n', 'build')
    }

    Write-Host 'Running tests'
    foreach ($package in $packages) {
        Invoke-Crate $package {
            Invoke-Native $alr @('-n', 'exec', '--', 'gprbuild', '-P', 'counter_tests.gpr')
            Invoke-Native $alr @('-n', 'exec', '--', '.\bin\test_counter.exe')
        }
    }

    Write-Host 'Launching Counter'
    Invoke-Crate $app {
        Invoke-Native $alr @('-n', 'exec', '--', '.\bin\counter_windows.exe')
    }
}
