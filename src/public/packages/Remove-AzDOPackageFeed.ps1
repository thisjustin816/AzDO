<#
.SYNOPSIS
Removes an Azure Artifacts package feed.

.DESCRIPTION
Removes an Azure Artifacts package feed.

.PARAMETER Name
Name of the feed to remove.

.PARAMETER Project
Project that the feed to remove is in. If no project is specified, it will look for an organization-scoped feed.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[orgranization]).

.PARAMETER Force
Force feed removal without confirmation.

.PARAMETER Pat
Personal access token authorized to administer Azure Artifacts. Defaults to $env:SYSTEM_ACCESSTOKEN for use in
Azure Pipelines.

.EXAMPLE
Remove-AzDOPackageFeed -FeedName MyFeed

.EXAMPLE
Remove-AzDOPackageFeed -FeedName MyFeed -Project MyProject

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Remove-AzDOPackageFeed {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Name')]
    param (
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [Alias('feed')]
        [String[]]$Name,
        [Parameter(ParameterSetName = 'ID', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Id,
        [Switch]$Force,
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
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
        if ($null -eq $Project) {
            [String]$Project = @('')
        }

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
            if ($PSCmdlet.ShouldProcess($CollectionUri, "Remove feed $Name - $feedId")) {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Delete `
                    -SubDomain 'feeds' `
                    -Project $Project `
                    -Endpoint "packaging/feeds/$feedId" `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false `
                    -Confirm:$false
            }
        }
    }
}
