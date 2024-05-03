[CmdletBinding()]
param (
    [String]$Name = 'AzDOCmd',
    [String]$SourceDirectory = "$PSScriptRoot/src"
)

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
$config = [PesterConfiguration]::Default
$config.Filter.Tag = 'Unit'
$config.Run.Path = $SourceDirectory
$config.Run.Exit = $true
$config.Run.Throw = $true
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config