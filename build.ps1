﻿[CmdletBinding()]
param (
    [String]$Name = 'AzDOCmd',
    [String]$Version = '0.0.1',
    [String]$SourceDirectory = "$PSScriptRoot/src",
    [String]$OutputDirectory = "$PSScriptRoot/out"
)

Remove-Item -Path $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
$ModuleOutputDirectory = "$OutputDirectory/$Name/$Version"

Invoke-ScriptAnalyzer -Path $SourceDirectory -Recurse -Severity Information

$null = New-Item -Path "$ModuleOutputDirectory/$name.psm1" -ItemType File -Force
$functionNames = @()
$moduleContent = @()
Get-ChildItem -Path "$SourceDirectory/public" -Filter '*.ps1' -Exclude '*.Tests.ps1' -File -Recurse |
    ForEach-Object -Process {
        $functionName = $_.BaseName
        $functionNames += $functionName
        $functionContent = Get-Content -Path $_.FullName

        # Remove any init blocks outside of the function
        $startIndex = (
            $functionContent.IndexOf('<#'),
            $functionContent.IndexOf($functionContent -match "function $functionName")[0]
        ) | Where-Object -FilterScript { $_ -ge 0 } | Sort-Object | Select-Object -First 1
        $functionContent = $functionContent[$startIndex..($functionContent.Length - 1)]
        # Format the private function dot sources for the expected folder structure
        $functionContent = $functionContent.Replace('../../private', 'private')

        $moduleContent += ''
        $moduleContent += $functionContent
    }
$moduleContent | Set-Content -Path "$ModuleOutputDirectory/$name.psm1" -Force
$null = New-Item -Path "$ModuleOutputDirectory/private" -ItemType Directory -Force
Get-ChildItem -Path "$SourceDirectory/private" -Exclude '*.Tests.ps1' |
    Copy-Item -Destination "$ModuleOutputDirectory/private" -Recurse -Force

$manifestPath = "$ModuleOutputDirectory/$Name.psd1"
$repoUrl = ( & git config --get remote.origin.url ).Replace('.git', '')
$companyName = if ($repoUrl -match 'github') {
    $repoUrl.Split('/')[3]
}
else {
    $env:USERDOMAIN
}
$requiredModulesStatement = Get-Content -Path "$SourceDirectory\$Name.psm1" |
    Where-Object -FilterScript { $_ -match '#Requires' }
$requiredModules = (($requiredModulesStatement -split '-Modules ')[1] -split ',').Trim()
$newModuleManifest = @{
    Path = $manifestPath
    Author = ( & git log --format='%aN' | Sort-Object -Unique )
    CompanyName = $companyName
    Copyright = "(c) $( Get-Date -Format yyyy ) $companyName. All rights reserved."
    RootModule = "$Name.psm1"
    ModuleVersion = $Version
    Description = 'A module for interacting with Azure DevOps.'
    PowerShellVersion = 5.1
    FunctionsToExport = $functionNames
    CompatiblePSEditions = ('Desktop', 'Core')
    Tags = @('Azure DevOps', 'DevOps', 'Azure', 'Pipelines')
    ProjectUri = $repoUrl
    LicenseUri = 'https://opensource.org/licenses/MIT'
    ReleaseNotes = ( git log -1 --pretty=%B )[0]
}
if ($requiredModules) {
    $newModuleManifest['RequiredModules'] = $requiredModules
}
New-ModuleManifest @newModuleManifest
Get-Item -Path $manifestPath

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
$config = [PesterConfiguration]::Default
$config.Run.Path = $SourceDirectory
$config.Run.Exit = $true
$config.Run.Throw = $true
$config.Output.Verbosity = 'Detailed'
# TODO: Fix Tests
# Invoke-Pester -Configuration $config

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module -Name $manifestPath -Force -PassThru
