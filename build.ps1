[CmdletBinding()]
param (
    [String]$Name = 'AzDO',
    [String]$Version,
    [String]$SourceDirectory = "$PSScriptRoot/src",
    [String]$OutputDirectory = "$PSScriptRoot/out"
)

Remove-Item -Path $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
$ModuleOutputDirectory = "$OutputDirectory/$Name"
if ($Version) {
    $ModuleOutputDirectory += "/$Version"
}

Invoke-ScriptAnalyzer -Path $SourceDirectory -Recurse -Severity Information

New-Item -Path "$ModuleOutputDirectory/$name.psm1" -ItemType File -Force
$moduleNames = @()
$moduleContent = @()
Get-ChildItem -Path "$SourceDirectory/public" -Filter '*.ps1' -Exclude '*.Tests.ps1' -File -Recurse |
    ForEach-Object -Process {
        $moduleNames += $_.BaseName
        $functionContent = Get-Content -Path $_.FullName

        # Remove any init blocks outside of the function
        $startIndex = (
            $functionContent.IndexOf('<#'),
            $functionContent.IndexOf($functionContent -match 'function')[0]
        ) | Sort-Object | Select-Object -First 1
        $functionContent = $functionContent[$startIndex..($functionContent.Length - 1)]
        # Format the private function dot sources for the expected folder structure
        $functionContent = $functionContent.Replace('../../private', 'private')

        $moduleContent += $functionContent
    }
$moduleContent | Set-Content -Path "$ModuleOutputDirectory/$name.psm1" -Force
New-Item -Path "$ModuleOutputDirectory/private" -ItemType Directory -Force
Get-ChildItem -Path "$SourceDirectory/private" -Exclude '*.Tests.ps1' |
    Copy-Item -Destination "$ModuleOutputDirectory/private" -Recurse -Force

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module -Name "$SourceDirectory/$name.psm1" -Force

#$config = [PesterConfiguration]::Default
#$config.Run.Path = $SourceDirectory
#$config.Run.Exit = $true
#$config.Run.Throw = $true
#$config.Output.Verbosity = 'Detailed'
#Invoke-Pester -Configuration $config
