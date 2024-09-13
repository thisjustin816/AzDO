<#
.SYNOPSIS
Removes a retention policy for a package feed.

.DESCRIPTION
Removes a retention policy for a package feed.

.PARAMETER Name
Name of the feed.

.PARAMETER Id
GUID of the feed.

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
https://docs.microsoft.com/en-us/rest/api/azure/devops/artifacts/retention-policies/delete-retention-policy

.NOTES
N/A
#>
function Remove-AzDOPackageFeedRetention {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Name')]
    param (
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [Alias('feed')]
        [String[]]
        $Name,

        [Parameter(ParameterSetName = 'ID', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]
        $Id,

        [Switch]
        $NoRetry,

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
            if ($PSCmdlet.ShouldProcess($feedId, 'Remove feed retention policy.')) {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Delete `
                    -SubDomain 'feeds' `
                    -Project $Project `
                    -Endpoint "packaging/feeds/$feedId/retentionpolicies" `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false `
                    -Confirm:$false
            }
        }
    }
}
