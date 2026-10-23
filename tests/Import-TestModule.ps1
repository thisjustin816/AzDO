$sourceManifest = Import-PowerShellDataFile -LiteralPath "$PSScriptRoot/../src/AzDOCmd.psd1"
$version = $sourceManifest.ModuleVersion
Import-Module -Name "$PSScriptRoot/../out/AzDOCmd/$version/AzDOCmd.psd1" -Force -ErrorAction Stop
