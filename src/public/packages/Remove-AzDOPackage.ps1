<#
.SYNOPSIS
Removes a package version from an Azure Artifacts feed.

.DESCRIPTION
Removes a package version from an Azure Artifacts feed.

.PARAMETER Name
Name of the package to remove.

.PARAMETER Version
Version of the named package to remove.

.PARAMETER Feed
Name or ID of the feed that the package is in.

.PARAMETER Provider
The package provider. (e.g. Nuget, npm)

.PARAMETER Project
Project that the package's feed is scoped to. If nothing is specified it will look for organization-scoped feed.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to administer Azure Artifacts feeds.

.PARAMETER Force
Don't prompt for confirmation to remove the package.

.EXAMPLE
Get-AzDOPackage -PackageName PSSiOps -Version 9.9.9 -Feed MyFeed | Remove-AzDOPackage

.NOTES
N/A
#>
function Remove-AzDOPackage {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('name')]
        [String[]]$PackageName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('versions')]
        [System.Object[]]$Version,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('feedId')]
        [System.Object]$Feed,

        [ValidateSet('nuget', 'upack', 'npm')]
        [String]$Provider = 'nuget',

        [Switch]
        $Force,

        [Switch]
        $NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [System.Object]$Project,

        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '5.1-preview.1'
        }
        [Regex]$GuidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName
        if ($null -eq $Project) {
            $Project = @('')
        }

        foreach ($name in $PackageName) {
            foreach ($versionNumber in $Version) {
                if ($Feed -notmatch $GuidRegex) {
                    $feedId = Get-AzDOPackage `
                        -PackageName $name `
                        -Version $versionNumber `
                        -Feed $Feed `
                        -Project $Project `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat `
                        -NoRetry:$NoRetry |
                        Select-Object -ExpandProperty feedId
                }
                else {
                    $feedId = $Feed
                }
                if ($versionNumber -isnot [String]) {
                    $versionNumber = $versionNumber.version
                }

                $endpoint = "packaging/feeds/$feedId/$Provider"
                if ($Provider -ne 'npm') {
                    $endpoint += '/packages'
                }
                $endpoint += "/$name/versions/$versionNumber"
                $deleteArgs = @{
                    Method    = 'Delete'
                    Subdomain = 'pkgs'
                    Endpoint  = $endpoint
                    NoRetry   = $NoRetry
                    WhatIf    = $false
                    Confirm   = $false
                }
                if ($Provider -eq 'nuget' -and ![String]::IsNullOrEmpty($Project)) {
                    $deleteArgs['Project'] = $Project
                }
                if (!$Force) {
                    $ConfirmPreference = 'Low'
                }
                if ($PSCmdlet.ShouldProcess("Feed $Feed", "Delete $name $versionNumber")) {
                    Invoke-AzDORestApiMethod @script:AzApiHeaders @deleteArgs
                }
            }
        }
    }
}
