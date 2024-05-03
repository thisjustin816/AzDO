[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [String]$Name = 'AzDOCmd',
    [String]$OutputDirectory = "$PSScriptRoot/out",
    [String]$PSGalleryApiKey = $env:PSGALLERYAPIKEY,
    [bool]$Build = $true,
    [bool]$Test = $true
)

if ($Build) {
    & $PSScriptRoot/build.ps1
}
if ($Test) {
    & $PSScriptRoot/test.ps1
}

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue

$versionedFolder = Get-ChildItem -Path "$OutputDirectory/$Name" | Select-Object -Last 1
if ($versionedFolder) {
    Import-Module -Name "$($versionedFolder.FullName)/$Name.psd1" -Force -PassThru
    if ($PSCmdlet.ShouldProcess("$Name $($versionedFolder.BaseName)", "Publish-Module")) {
        Publish-Module `
            -Path $versionedFolder.FullName `
            -NuGetApiKey $PSGalleryApiKey  
    }
}
else {
    Write-Warning -Message "No module named $Name found to publish."
}