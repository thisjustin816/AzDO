#Requires -Version 7.4
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
Import-Module -FullyQualifiedName @{
    ModuleName = 'PSModuleUtils'; ModuleVersion = '5.0.0'; MaximumVersion = '5.999.999'
} -ErrorAction Stop
Publish-PSModule -Name 'AzDOCmd' -OutputDirectory "$PSScriptRoot/out" -Confirm:(-not $env:GITHUB_ACTIONS)
