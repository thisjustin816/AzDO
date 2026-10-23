#Requires -Version 7.4
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    Import-Module -FullyQualifiedName @{
        ModuleName = 'PSModuleUtils'; ModuleVersion = '5.0.0'; MaximumVersion = '5.999.999'
    } -ErrorAction Stop
    if (-not $env:GITHUB_ACTIONS) {
        Invoke-PSModuleAnalyzer -Fix
    }
    $builtManifest = Build-PSModule
    Test-PSModule -Name $builtManifest.BaseName -Tag 'Unit'
    $builtManifest
}
finally {
    Pop-Location
}
