[CmdletBinding()]
param (
    [String]$Name = 'AzDO',
    [String]$Version = '0.0.1'
)

$OutDirectory = "$PSScriptRoot/out/$Name"

Invoke-ScriptAnalyzer -Path "$PSScriptRoot/src" -Recurse -Severity Information

Remove-Item -Path "$PSScriptRoot/out" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$OutDirectory/$name.psm1" -ItemType File -Force
$moduleNames = @()
$moduleContent = @()
Get-ChildItem -Path "$PSScriptRoot/src/public" -Filter '*.ps1' -Exclude '*.Tests.ps1' -File -Recurse |
    ForEach-Object -Process {
        $moduleNames += $_.BaseName
        $moduleContent += ''
        $moduleContent += ( Get-Content -Path $_.FullName ).Replace('../../private', 'private')
    }
$moduleContent | Set-Content -Path "$OutDirectory/$name.psm1" -Force
New-Item -Path "$OutDirectory/private" -ItemType Directory -Force
Get-ChildItem -Path "$PSScriptRoot/src/private" -Exclude '*.Tests.ps1' |
    Copy-Item -Destination "$OutDirectory/private" -Recurse -Force

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module -Name "$PSScriptRoot/src/$name.psm1" -Force

#$config = [PesterConfiguration]::Default
#$config.Run.Path = "$PSScriptRoot/src"
#$config.Run.Exit = $true
#$config.Run.Throw = $true
#$config.Output.Verbosity = 'Detailed'
#Invoke-Pester -Configuration $config
