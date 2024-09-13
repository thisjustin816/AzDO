<#
.SYNOPSIS
Sets a retention policy for a package feed.

.DESCRIPTION
Sets a retention policy for a package feed.

.PARAMETER Name
Name of the feed.

.PARAMETER Id
GUID of the feed.

.PARAMETER Count
Maximum versions to preserve per package and package type.

.PARAMETER Days
Number of days to preserve a package version after its latest download.

.PARAMETER Project
Project that the feed is scoped to. If nothing is specified, it will look for Organization-scoped feeds.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Force
Bypass confirmation.

.PARAMETER Pat
A personal access token authorized to access feeds.

.EXAMPLE
Get-AzDOPackageFeed -Name MyFeed | Set-AzDOPackageFeedRetention

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/artifacts/retention-policies/set-retention-policy

.NOTES
N/A
#>
function Set-AzDOPackageFeedRetention {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Name')]
    param (
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [Alias('feed')]
        [String[]]
        $Name,

        [Parameter(ParameterSetName = 'ID', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]
        $Id,

        [Int]
        $Count = 5000,

        [Int]
        $Days = 365,

        [Switch]$NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]
        $Project,

        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [Switch]
        $Force,

        [String]
        $Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1-preview.1'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $Id = Get-AzDOPackageFeed `
                -Name $Name `
                -Project $Project `
                -CollectionUri $CollectionUri `
                -Pat $Pat `
                -NoRetry:$NoRetry |
                Select-Object `
                    -ExpandProperty id
        }
        if (!$Force) {
            $ConfirmPreference = 'Low'
        }
        foreach ($feedId in $Id) {
            $shouldProcessPrompt = (
                "Set feed retention policy. Package count limit: $Count, " +
                "days to keep recently downloaded packages: $Days"
            )
            if ($PSCmdlet.ShouldProcess($feedId, $shouldProcessPrompt)) {
                $body = [PSCustomObject]@{
                    countLimit                           = $Count
                    daysToKeepRecentlyDownloadedPackages = $Days
                } | ConvertTo-Json

                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Put `
                    -SubDomain 'feeds' `
                    -Project $Project `
                    -Endpoint "packaging/feeds/$feedId/retentionpolicies" `
                    -Body $body `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false `
                    -Confirm:$false
            }
        }
    }
}
